#!/bin/bash
# ---------------------------------------------------------------------------
# node1~5 — k3s 에이전트(워커) 설치
#
#   sudo ./k3s-agent.sh <노드IP> <라벨> "<토큰>"
#
# 예
#   sudo ./k3s-agent.sh 192.168.56.11 web   "K10abc..."
#   sudo ./k3s-agent.sh 192.168.56.14 batch "K10abc..."
#   sudo ./k3s-agent.sh 192.168.56.15 infra "K10abc..."
# ---------------------------------------------------------------------------
set -euo pipefail

NODE_IP="${1:?사용법: $0 <노드IP> <web|batch|infra> <토큰>}"
LABEL="${2:?사용법: $0 <노드IP> <web|batch|infra> <토큰>}"
TOKEN="${3:?사용법: $0 <노드IP> <web|batch|infra> <토큰>}"
SERVER="https://192.168.56.10:6443"

# 🔴 사설망 인터페이스. k3s-server.sh 의 설명 참조.
IFACE="enp0s8"

echo "=== k3s 에이전트 설치 ==="
echo "  IP    : ${NODE_IP}"
echo "  라벨  : workload=${LABEL}"
echo

curl -sfL https://get.k3s.io | \
  K3S_URL="${SERVER}" K3S_TOKEN="${TOKEN}" sh -s - agent \
  --selinux \
  --flannel-iface="${IFACE}" \
  --node-ip="${NODE_IP}" \
  --node-label="workload=${LABEL}"

# 🔴 --node-ip 와 --flannel-iface 를 둘 다 줘야 한다.
#    --node-ip 만 주면 노드 주소는 맞지만 VXLAN 터널이 NAT 인터페이스로 맺혀
#    노드 간 파드 통신이 안 된다.
# 라벨은 여기서 붙인다. taint 는 node0 에서 setup-cluster.sh 로 건다
#   (에이전트 설치 시 taint 를 걸면 자기 자신도 못 뜨는 경우가 있어 분리)

echo
echo "=== 확인 ==="
systemctl status k3s-agent --no-pager | head -5
echo
echo "  node0 에서 'kubectl get nodes' 로 Ready 여부를 확인할 것"
