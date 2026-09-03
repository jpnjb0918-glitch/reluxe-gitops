#!/bin/bash
# ===========================================================================
# [node0 → node4] 애플리케이션 이미지 빌드
#
# 왜 node4 인가
#   크롤러 이미지가 2.7GB 다. 빌드하는 동안 CPU·디스크를 크게 쓴다.
#   웹 노드에서 하면 서비스 응답이 흔들리므로 배치 노드로 분리했다.
#
# 🔴 docker 가 아니라 podman 을 쓰는 이유
#   k3s 는 컨테이너 런타임으로 containerd 를 쓴다. Docker 데몬이 없다.
#   podman 은 데몬 없이 도는 도구라 이런 환경에 맞는다.
#   (Jenkins 파이프라인에서는 같은 이유로 Buildah 를 쓴다)
# ===========================================================================
set -euo pipefail

REG="192.168.56.15:30500"
SRC="https://github.com/epqlffltm/CloudeDX.git"
N4="ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR vagrant@192.168.56.14"

echo ""
echo "==========================================================="
echo " [3/9] 애플리케이션 이미지 빌드"
echo "==========================================================="
echo ""
echo "  이미지 2종을 만든다"
echo "    reverdi-backend   564MB   FastAPI 웹 + API"
echo "    reverdi-crawler   2.7GB   Playwright + Chromium 포함"
echo ""
echo "  ⏱  15~30분 걸린다. 크롤러가 브라우저를 통째로 받기 때문이다."
echo "     중간에 멈춘 것처럼 보여도 정상이다."
echo ""

$N4 "sudo dnf install -y -q podman >/dev/null 2>&1; echo '  podman 설치 확인'"

echo "--- 소스 받기 ---"
$N4 "rm -rf ~/CloudeDX && git clone --depth 1 -q ${SRC} ~/CloudeDX && echo '    완료'"

echo ""
echo "--- 백엔드 이미지 (564MB) ---"
$N4 "cd ~/CloudeDX && sudo podman build -q -f dockerfile.backend -t ${REG}/reverdi-backend:dev . >/dev/null && echo '    빌드 완료'"
$N4 "sudo podman push --tls-verify=false ${REG}/reverdi-backend:dev 2>&1 | tail -2"

echo ""
echo "--- 크롤러 이미지 (2.7GB · 오래 걸림) ---"
$N4 "cd ~/CloudeDX && sudo podman build -q -f dockerfile.crawler -t ${REG}/reverdi-crawler:dev . >/dev/null && echo '    빌드 완료'"
$N4 "sudo podman push --tls-verify=false ${REG}/reverdi-crawler:dev 2>&1 | tail -2"

echo ""
curl -s "http://${REG}/v2/_catalog" && echo ""
echo "  ✅ 이미지 준비 완료"
