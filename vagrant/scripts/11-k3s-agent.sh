#!/bin/bash
# ===========================================================================
# [node1~5] k3s 에이전트 = 워커 노드
#
#   사용법: 11-k3s-agent.sh <노드IP> <web|batch|infra>
#
# 라벨을 여기서 붙인다. taint 는 나중에 node0 에서 건다.
# 에이전트 설치 시점에 taint 를 걸면 자기 자신이 못 뜨는 경우가 있어 분리했다.
# ===========================================================================
set -euo pipefail

NODE_IP="${1:?사용법: $0 <노드IP> <라벨>}"
LABEL="${2:?사용법: $0 <노드IP> <라벨>}"

SERVER="https://192.168.56.10:6443"
IFACE="enp0s8"                                  # 사설망 (10-k3s-server.sh 설명 참조)
TOKEN="reverdi-local-cluster-token-2026"        # 서버와 같은 값

echo ""
echo "==========================================================="
echo " [$(hostname)] k3s 에이전트 — IP ${NODE_IP} · 라벨 workload=${LABEL}"
echo "==========================================================="
echo ""
echo "  이 노드의 역할"
case "$LABEL" in
  web)   echo "   웹 파드 + DB 파드. 서비스가 실제로 도는 곳" ;;
  batch) echo "   크롤러 · 이미지 빌드. 무거운 작업을 웹과 분리한다" ;;
  infra) echo "   레지스트리 · Jenkins · Argo CD · 모니터링" ;;
esac
echo ""

# 서버가 뜰 때까지 기다린다.
# Vagrant 가 node0 을 먼저 올리지만, API 서버가 준비되기까지 시간이 걸린다.
echo "  컨트롤 플레인 대기 중..."
for i in $(seq 1 60); do
  if curl -sk --max-time 3 "${SERVER}/ping" >/dev/null 2>&1; then
    echo "    응답 확인 ($i회차)"
    break
  fi
  sleep 5
done

curl -sfL https://get.k3s.io | \
  K3S_URL="${SERVER}" K3S_TOKEN="${TOKEN}" sh -s - agent \
  --selinux \
  --flannel-iface="${IFACE}" \
  --node-ip="${NODE_IP}" \
  --node-label="workload=${LABEL}"

sleep 5
echo ""
echo "  flannel 인터페이스 확인 (local 이 ${NODE_IP} 여야 정상):"
ip -d link show flannel.1 2>/dev/null | grep -o 'local [0-9.]*' || echo "    (아직 생성 전)"
echo ""
echo "  ✅ ${LABEL} 노드 준비 완료"
echo ""
