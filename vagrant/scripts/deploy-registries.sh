#!/bin/bash
# ---------------------------------------------------------------------------
# 호스트(윈도우 WSL 또는 리눅스)에서 실행 — registries.yaml 을 전 노드에 배포
#
# 🔴 이 파일은 kubectl apply 대상이 아니다.
#    쿠버네티스 리소스가 아니라 k3s(containerd) 의 노드 설정 파일이다.
#    한 대라도 빠지면 그 노드에서만 ImagePullBackOff 가 난다.
#
#   ./deploy-registries.sh
# ---------------------------------------------------------------------------
set -euo pipefail
SRC="${1:-infra/registries.yaml}"

[ -f "$SRC" ] || { echo "🔴 $SRC 가 없다"; exit 1; }

for n in node0 node1 node2 node3 node4 node5; do
  echo "=== $n ==="
  # vagrant ssh 로 파일을 밀어넣는다 (scp 설정 없이도 동작)
  vagrant ssh "$n" -c "sudo mkdir -p /etc/rancher/k3s && sudo tee /etc/rancher/k3s/registries.yaml >/dev/null" < "$SRC"

  # node0 은 k3s, 나머지는 k3s-agent
  if [ "$n" = "node0" ]; then
    vagrant ssh "$n" -c "sudo systemctl restart k3s"
  else
    vagrant ssh "$n" -c "sudo systemctl restart k3s-agent"
  fi
  echo "  적용 후 재시작 완료"
done

echo
echo "확인: node0 에서"
echo "  kubectl get nodes          ← 전부 Ready 로 돌아오는지"
echo "  curl http://192.168.56.15:30500/v2/_catalog"
