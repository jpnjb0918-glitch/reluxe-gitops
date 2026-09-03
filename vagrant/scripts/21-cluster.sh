#!/bin/bash
# ===========================================================================
# [node0] taint · 네임스페이스 · SSH 키
#
# 라벨과 taint 의 차이
#   라벨(nodeSelector)  "이 파드를 어디로 보낼지"  — 파드 입장
#   taint/toleration    "이 노드에 누가 들어올지"  — 노드 입장
#
#   라벨만 있으면 다른 파드가 그 노드로 새어 들어오는 걸 막지 못한다.
#   둘 다 있어야 격리가 완성된다.
# ===========================================================================
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/home/vagrant/.kube/config}

echo ""
echo "==========================================================="
echo " [1/9] 클러스터 기본 구성"
echo "==========================================================="

echo "--- 노드 6대가 Ready 될 때까지 대기 ---"
for i in $(seq 1 60); do
  READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo 0)
  echo "    Ready ${READY}/6"
  [ "$READY" -ge 6 ] && break
  sleep 5
done
kubectl get nodes -o wide

echo ""
echo "--- 라벨 확인 ---"
# 에이전트 설치 때 이미 붙였지만, 빠진 경우를 대비해 보정한다.
kubectl label node node1 node2 node3 workload=web   --overwrite >/dev/null
kubectl label node node4              workload=batch --overwrite >/dev/null
kubectl label node node5              workload=infra --overwrite >/dev/null
kubectl get nodes -L workload

echo ""
echo "--- taint ---"
# 🔴 node4·node5 에 taint 를 걸면, toleration 이 있는 파드만 들어온다.
#    크롤러(2.7GB·Chromium)가 웹 노드에 뜨면 서비스 응답이 흔들린다.
kubectl taint node node4 workload=batch:NoSchedule --overwrite >/dev/null
kubectl taint node node5 workload=infra:NoSchedule --overwrite >/dev/null
kubectl get nodes -o custom-columns='NODE:.metadata.name,TAINTS:.spec.taints[*].key'
echo ""
echo "    node0 CriticalAddonsOnly  컨트롤 플레인 격리"
echo "    node4 workload            batch toleration 있는 파드만"
echo "    node5 workload            infra toleration 있는 파드만"

echo ""
echo "--- 네임스페이스 ---"
# 한 클러스터에 여러 구성요소가 산다. 구역을 나누면
# 실수로 남의 것을 지우는 사고를 막고, 나중에 권한·할당량도 구역 단위로 건다.
for ns in reverdi infra argocd monitoring; do
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns" >/dev/null
done
kubectl get ns | grep -E "reverdi|infra|argocd|monitoring"

echo ""
echo "--- 노드 간 SSH 키 ---"
# 이후 단계에서 node0 이 node4(이미지 빌드)·전 노드(registries.yaml)에
# 명령을 보내야 한다. 매번 비밀번호를 묻지 않도록 키를 배포한다.
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519 -q
sudo dnf install -y -q sshpass >/dev/null 2>&1 || true
for ip in 11 12 13 14 15; do
  sshpass -p vagrant ssh-copy-id -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    vagrant@192.168.56.$ip >/dev/null 2>&1 && echo "    192.168.56.$ip 키 배포"
done

echo ""
echo "  ✅ 클러스터 기본 구성 완료"
