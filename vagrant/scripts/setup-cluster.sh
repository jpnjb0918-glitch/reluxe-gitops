#!/bin/bash
# ---------------------------------------------------------------------------
# node0 에서 실행 — taint · 네임스페이스 · 레지스트리 설정
#
# 전 노드가 Ready 가 된 뒤에 돌린다.
#   kubectl get nodes    ← 6대 전부 Ready 확인 후
# ---------------------------------------------------------------------------
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}

echo "=== [1/4] 노드 상태 확인 ==="
kubectl get nodes -o wide
READY=$(kubectl get nodes --no-headers | grep -c " Ready ") || true
if [ "$READY" -lt 6 ]; then
  echo "🔴 Ready 노드가 ${READY}대뿐이다. 6대가 될 때까지 기다린 뒤 다시 실행할 것."
  exit 1
fi

echo
echo "=== [2/4] 라벨 확인 ==="
# 라벨은 k3s-agent.sh 에서 --node-label 로 이미 붙였다. 빠졌으면 여기서 보정한다.
kubectl label node node1 node2 node3 workload=web   --overwrite
kubectl label node node4              workload=batch --overwrite
kubectl label node node5              workload=infra --overwrite
kubectl get nodes -L workload

echo
echo "=== [3/4] taint ==="
# 🔴 label 만으로는 부족하다. label 은 "어디로 갈지"만 정하고,
#    다른 파드가 그 노드로 새어 들어오는 것을 막지 못한다.
#    taint 를 걸어야 toleration 이 있는 파드만 들어온다.
kubectl taint node node4 workload=batch:NoSchedule --overwrite
kubectl taint node node5 workload=infra:NoSchedule --overwrite
kubectl get nodes -o custom-columns='NODE:.metadata.name,TAINTS:.spec.taints[*].key'

echo
echo "=== [4/4] 네임스페이스 ==="
for ns in reluxe infra argocd monitoring; do
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns"
done
kubectl get ns

echo
echo "완료. 다음 순서:"
echo "  1) kubectl apply -f infra/registry.yaml"
echo "  2) registries.yaml 을 전 노드에 배포  → scripts/deploy-registries.sh"
echo "  3) CloudNativePG 오퍼레이터 설치"
echo "  4) kubectl apply -f infra/postgres-cluster.yaml"
