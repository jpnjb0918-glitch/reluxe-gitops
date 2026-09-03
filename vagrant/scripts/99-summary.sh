#!/bin/bash
# ===========================================================================
# [node0] 구축 완료 — 접속 정보와 다음 할 일
#
# 비밀번호는 전부 무작위로 만들어졌다. 파일에 적어두지 않는다.
# 필요할 때마다 아래 명령으로 꺼내 쓴다.
# ===========================================================================
set -uo pipefail
export KUBECONFIG=${KUBECONFIG:-/home/vagrant/.kube/config}

APP_PW=$(kubectl get secret reverdi-secret -n reverdi -o jsonpath='{.data.ADMIN_PASSWORD}' 2>/dev/null | base64 -d)
CLI_PW=$(kubectl get secret reverdi-secret -n reverdi -o jsonpath='{.data.CLIENT_PASSWORD}' 2>/dev/null | base64 -d)
DB_PW=$(kubectl get secret reverdi-db-app -n reverdi -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
GRA_PW=$(kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d)
ARG_PW=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
JEN_PW=$(kubectl exec -n infra svc/jenkins -c jenkins -- cat /run/secrets/additional/chart-admin-password 2>/dev/null)

cat <<BANNER

███████████████████████████████████████████████████████████████
   구축 완료
███████████████████████████████████████████████████████████████

BANNER

echo "───────────────────────────────────────────────────────────"
echo " 접속 주소와 계정"
echo "───────────────────────────────────────────────────────────"
printf "\n"
printf "  %-14s %-34s %s\n" "서비스" "주소" "계정"
printf "  %-14s %-34s %s\n" "──────" "──────────────────────────────────" "──────────────────────"
printf "  %-14s %-34s %s\n" "웹 앱"    "http://192.168.56.11:30080"  "admin / ${APP_PW:-확인필요}"
printf "  %-14s %-34s %s\n" ""         ""                            "client / ${CLI_PW:-확인필요}"
printf "  %-14s %-34s %s\n" "Argo CD"  "http://192.168.56.11:30081"  "admin / ${ARG_PW:-확인필요}"
printf "  %-14s %-34s %s\n" "Grafana"  "http://192.168.56.11:30300"  "admin / ${GRA_PW:-확인필요}"
printf "  %-14s %-34s %s\n" "Jenkins"  "http://192.168.56.11:30808"  "admin / ${JEN_PW:-확인필요}"
printf "  %-14s %-34s %s\n" "레지스트리" "http://192.168.56.15:30500/v2/_catalog" "-"
printf "  %-14s %-34s %s\n" "DB"       "reverdi-db-rw.reverdi.svc:5432" "reverdi / ${DB_PW:-확인필요}"
printf "\n"
echo "  ※ .12 · .13 으로도 접속됩니다. NodePort 는 어느 노드로 들어와도 됩니다."

cat <<'HOWTO'

───────────────────────────────────────────────────────────
 비밀번호를 다시 확인하는 방법
───────────────────────────────────────────────────────────

  비밀번호는 설치할 때마다 새로 만들어집니다.
  아래 명령으로 언제든 다시 꺼낼 수 있습니다.
  (vagrant ssh node0 로 접속한 뒤 실행)

  ── 웹 앱 admin ────────────────────────────────────────
  kubectl get secret reverdi-secret -n reverdi \
    -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d ; echo

  ── 웹 앱 client ───────────────────────────────────────
  kubectl get secret reverdi-secret -n reverdi \
    -o jsonpath='{.data.CLIENT_PASSWORD}' | base64 -d ; echo

  ── DB ────────────────────────────────────────────────
  kubectl get secret reverdi-db-app -n reverdi \
    -o jsonpath='{.data.password}' | base64 -d ; echo

  ── Grafana ───────────────────────────────────────────
  kubectl get secret grafana-admin -n monitoring \
    -o jsonpath='{.data.admin-password}' | base64 -d ; echo

  ── Argo CD ───────────────────────────────────────────
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d ; echo

  ── Jenkins ───────────────────────────────────────────
  kubectl exec -n infra svc/jenkins -c jenkins -- \
    cat /run/secrets/additional/chart-admin-password ; echo

  ── DB 에 직접 접속 ────────────────────────────────────
  kubectl exec -it -n reverdi reverdi-db-1 -- psql -U postgres -d reverdi
  (파드 안에서 postgres 슈퍼유저로 들어가므로 비밀번호가 필요 없습니다)


───────────────────────────────────────────────────────────
 🔴 자동화하지 못한 것 — 직접 해주세요
───────────────────────────────────────────────────────────

  Jenkins 파이프라인을 돌리려면 GitHub 토큰이 필요합니다.
  개인 자격증명이라 스크립트에 넣을 수 없습니다.

  [1] 토큰 발급
      github.com → 프로필 → Settings → Developer settings
      → Personal access tokens → Tokens (classic)
      → Generate new token → 🔴 repo 체크 → 생성
      → ghp_... 값을 복사 (한 번만 보입니다)

  [2] Jenkins 에 등록
      http://192.168.56.11:30808 접속
      Jenkins 관리 → Credentials → System → Global → Add Credentials
        Kind      : Username with password
        Username  : <GitHub 아이디>
        Password  : <위에서 복사한 토큰>
        ID        : 🔴 gitops-push-token   ← 이 이름이어야 합니다
                    (Jenkinsfile 이 이 ID 로 찾습니다)

  [3] 파이프라인 생성
      새로운 Item → 이름 reverdi-ci → Pipeline 선택
        Definition : Pipeline script from SCM
        SCM        : Git
        URL        : https://github.com/epqlffltm/CloudeDX.git
        Branch     : */main
        Script Path: Jenkinsfile

      저장 → 지금 빌드 (첫 실행 15~25분)


───────────────────────────────────────────────────────────
 확인해볼 것
───────────────────────────────────────────────────────────

  ── 파드가 노드에 흩어졌는지 ───────────────────────────
  kubectl get pod -n reverdi -o wide
    웹 3개와 DB 3개가 node1·2·3 에 하나씩이면 정상입니다.
    topologySpreadConstraints 가 동작한 결과입니다.

  ── DB 페일오버 (발표 시연용) ──────────────────────────
  터미널 2개를 엽니다.

  창1) 조회를 계속 때린다
    while true; do printf '%s  ' "$(date +%H:%M:%S)"; \
      curl -s -o /dev/null -w "%{http_code}\n" -m 3 \
      http://192.168.56.11:30080/; sleep 1; done

  창2) primary 를 죽인다
    kubectl get cluster -n reverdi          # PRIMARY 확인
    kubectl delete pod -n reverdi reverdi-db-1
    kubectl get cluster -n reverdi          # 자동 승격 관찰

    → 창1 의 200 이 끊기지 않으면서 PRIMARY 가 바뀝니다.
      읽기는 replica 로 가기 때문입니다.

  ── Argo CD self-heal ─────────────────────────────────
  kubectl scale deploy reverdi-web -n reverdi --replicas=1
  kubectl get pod -n reverdi -w
    → 손으로 1개로 줄여도 Argo CD 가 3개로 되돌립니다.
      git 에 적힌 것이 정답이기 때문입니다.

  ── 크롤러 실행 ────────────────────────────────────────
  kubectl create job -n reverdi --from=cronjob/reverdi-crawler crawl-1
  kubectl logs -n reverdi -l job-name=crawl-1 -f
    → node4 에서만 돕니다 (taint 로 격리)

  ── Grafana 에서 앱 지표 ───────────────────────────────
  Explore → Prometheus → Code 모드 → 쿼리 입력
    http_requests_total
    sum(rate(http_requests_total[1m])) by (status)


───────────────────────────────────────────────────────────
 포트 정리
───────────────────────────────────────────────────────────

  30080  웹 앱          30300  Grafana
  30081  Argo CD        30500  레지스트리
  30808  Jenkins

  IP 는 node1(.11) ~ node5(.15) 아무거나 써도 됩니다.


───────────────────────────────────────────────────────────
 VM 관리
───────────────────────────────────────────────────────────

  vagrant halt          작업 끝나면 정지 (RAM 40GB 를 잡고 있습니다)
  vagrant up            다시 시작 — 클러스터는 그대로 복구됩니다
  vagrant ssh node0     접속 (kubectl · helm 은 여기서)
  vagrant destroy -f    전부 삭제하고 처음부터

HOWTO

echo ""
echo "───────────────────────────────────────────────────────────"
echo " 현재 상태"
echo "───────────────────────────────────────────────────────────"
echo ""
kubectl get nodes -o wide 2>/dev/null | head -8
echo ""
kubectl get pod -A -o wide 2>/dev/null | grep -vE "kube-system|Completed" | head -25
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
