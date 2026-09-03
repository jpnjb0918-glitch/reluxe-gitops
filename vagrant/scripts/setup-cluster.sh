#!/bin/bash
# ---------------------------------------------------------------------------
# node0 ?먯꽌 ?ㅽ뻾 ??taint 쨌 ?ㅼ엫?ㅽ럹?댁뒪 쨌 ?덉??ㅽ듃由??ㅼ젙
#
# ???몃뱶媛 Ready 媛 ???ㅼ뿉 ?뚮┛??
#   kubectl get nodes    ??6? ?꾨? Ready ?뺤씤 ??# ---------------------------------------------------------------------------
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}

echo "=== [1/4] ?몃뱶 ?곹깭 ?뺤씤 ==="
kubectl get nodes -o wide
READY=$(kubectl get nodes --no-headers | grep -c " Ready ") || true
if [ "$READY" -lt 6 ]; then
  echo "?뵶 Ready ?몃뱶媛 ${READY}?肉먯씠?? 6?媛 ???뚭퉴吏 湲곕떎由????ㅼ떆 ?ㅽ뻾??寃?"
  exit 1
fi

echo
echo "=== [2/4] ?쇰꺼 ?뺤씤 ==="
# ?쇰꺼? k3s-agent.sh ?먯꽌 --node-label 濡??대? 遺숈??? 鍮좎죱?쇰㈃ ?ш린??蹂댁젙?쒕떎.
kubectl label node node1 node2 node3 workload=web   --overwrite
kubectl label node node4              workload=batch --overwrite
kubectl label node node5              workload=infra --overwrite
kubectl get nodes -L workload

echo
echo "=== [3/4] taint ==="
# ?뵶 label 留뚯쑝濡쒕뒗 遺議깊븯?? label ? "?대뵒濡?媛덉?"留??뺥븯怨?
#    ?ㅻⅨ ?뚮뱶媛 洹??몃뱶濡??덉뼱 ?ㅼ뼱?ㅻ뒗 寃껋쓣 留됱? 紐삵븳??
#    taint 瑜?嫄몄뼱??toleration ???덈뒗 ?뚮뱶留??ㅼ뼱?⑤떎.
kubectl taint node node4 workload=batch:NoSchedule --overwrite
kubectl taint node node5 workload=infra:NoSchedule --overwrite
kubectl get nodes -o custom-columns='NODE:.metadata.name,TAINTS:.spec.taints[*].key'

echo
echo "=== [4/4] ?ㅼ엫?ㅽ럹?댁뒪 ==="
for ns in reverdi infra argocd monitoring; do
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns"
done
kubectl get ns

echo
echo "?꾨즺. ?ㅼ쓬 ?쒖꽌:"
echo "  1) kubectl apply -f infra/registry.yaml"
echo "  2) registries.yaml ?????몃뱶??諛고룷  ??scripts/deploy-registries.sh"
echo "  3) CloudNativePG ?ㅽ띁?덉씠???ㅼ튂"
echo "  4) kubectl apply -f infra/postgres-cluster.yaml"

