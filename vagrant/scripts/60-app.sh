#!/bin/bash
# ===========================================================================
# [node0] 애플리케이션 배포 (Helm)
#
# 저장소가 둘인 이유
#   CloudeDX   앱 소스 · Dockerfile · Jenkinsfile   ← 개발자가 커밋
#   reverdi    Helm 차트 · 인프라 매니페스트        ← Jenkins 가 이미지 태그만 커밋
#
#   🔴 같은 저장소에 두면 무한 루프가 난다.
#      Jenkins 가 빌드 → 태그 커밋 → 그 커밋이 Jenkins 를 다시 깨움 → 반복.
#
# Helm 훅
#   migrate-job 이 pre-install 훅이라 앱 파드보다 먼저 실행된다.
#   웹 파드 3개가 동시에 alembic 을 돌리면 경합하기 때문이다.
# ===========================================================================
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/home/vagrant/.kube/config}

GITOPS="https://github.com/jpnjb0918-glitch/reverdi.git"

echo ""
echo "==========================================================="
echo " [5/9] 애플리케이션 배포"
echo "==========================================================="

echo "--- 배포 저장소 clone ---"
rm -rf ~/reverdi && git clone -q "$GITOPS" ~/reverdi
cd ~/reverdi
echo "    $(ls charts/)"

# 🔴 윈도우에서 파일을 고치면 BOM(EF BB BF)이 붙거나 한글 주석이
#    U+0080 같은 문자로 깨질 수 있다. YAML 파서는 둘 다 거부한다.
#    file 명령과 UTF-8 디코딩이 통과해도 YAML 은 실패하므로 여기서 정리한다.
echo "--- YAML 인코딩 정리 (BOM · 제어문자) ---"
python3 - <<'PY'
import re, pathlib
pat = re.compile(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]')
n = 0
for p in pathlib.Path('.').rglob('*'):
    if '.git' in p.parts or not p.is_file(): continue
    if p.suffix not in ('.yaml', '.yml', '.tpl'): continue
    b = p.read_bytes()
    orig = b
    if b.startswith(b'\xef\xbb\xbf'): b = b[3:]          # BOM 제거
    try: s = b.decode('utf-8')
    except Exception: continue
    s2 = pat.sub('', s)                                   # 제어문자 제거
    if s2.encode('utf-8') != orig:
        p.write_bytes(s2.encode('utf-8')); n += 1
print(f"    {n}개 파일 정리")
PY

echo ""
echo "--- 차트 렌더링 검증 ---"
echo "    문법 오류를 클러스터에 올리기 전에 잡는다"
helm lint charts/reverdi
helm template reverdi charts/reverdi -f charts/reverdi/values-vagrant.yaml >/dev/null
echo "    통과"

echo ""
echo "--- 설치 ---"
echo "    ① migrate-job (Helm 훅) 이 alembic upgrade head 를 먼저 실행"
echo "    ② 끝나면 웹 파드 3개 생성"
echo "    ③ readinessProbe(/ready) 가 DB 확인 후 트래픽 수용"
helm upgrade --install reverdi charts/reverdi -n reverdi \
  -f charts/reverdi/values-vagrant.yaml --timeout 10m

echo ""
kubectl get pod -n reverdi -o wide
echo ""
echo "--- 응답 확인 ---"
for i in $(seq 1 30); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 3 http://192.168.56.11:30080/health || echo 000)
  [ "$CODE" = "200" ] && { echo "    /health → 200"; break; }
  sleep 5
done
curl -s http://192.168.56.11:30080/ready | python3 -m json.tool || true

echo ""
echo "  ✅ 앱 배포 완료 — http://192.168.56.11:30080"
