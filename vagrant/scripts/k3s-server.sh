#!/bin/bash
# ---------------------------------------------------------------------------
# node0 전용 — k3s 서버(컨트롤 플레인) 설치
#
#   vagrant ssh node0
#   sudo /vagrant-scripts/k3s-server.sh
#   (공유 폴더를 껐으므로 scp 나 붙여넣기로 옮겨서 실행)
# ---------------------------------------------------------------------------
set -euo pipefail

NODE_IP="192.168.56.10"

# 🔴 사설망 인터페이스 이름. Vagrant + VirtualBox 에서는 보통 enp0s8 이다.
#    enp0s3 는 Vagrant NAT(10.0.2.15)로 전 노드가 동일하므로 절대 쓰면 안 된다.
#    다르면 `ip -4 addr show | grep 192.168.56` 로 확인해 바꾼다.
IFACE="enp0s8"

echo "=== k3s 서버 설치 (node0) ==="
curl -sfL https://get.k3s.io | sh -s - server \
  --selinux \
  --disable=traefik \
  --disable=servicelb \
  --node-taint CriticalAddonsOnly=true:NoExecute \
  --flannel-iface="${IFACE}" \
  --node-ip="${NODE_IP}" \
  --advertise-address="${NODE_IP}" \
  --write-kubeconfig-mode 644

# --selinux            enforcing 유지. EKS 노드도 enforcing 이라 여기서 익혀야 한다
# --disable=traefik    🔴 EKS 에는 없다. 켜두면 나중에 Ingress 동작이 달라 헷갈린다
# --disable=servicelb  마찬가지. AWS 는 ALB 가 담당한다
# --node-taint         🔴 컨트롤 플레인에 워크로드가 안 뜨게 격리.
#                      EKS 는 컨트롤 플레인이 VPC 밖에 있어 애초에 섞이지 않는다
# --node-ip            🔴 필수. 안 주면 쿠버네티스가 Vagrant NAT(10.0.2.15)를 노드 주소로 쓴다
# --flannel-iface      🔴 필수. --node-ip 만으로는 부족하다.
#                      --node-ip 는 "쿠버네티스가 보는 노드 주소"만 바꾸고,
#                      Flannel(VXLAN)이 쓰는 인터페이스는 따로 지정해야 한다.
#                      빠지면 전 노드가 10.0.2.15 로 터널을 맺으려 해서
#                      "파드는 뜨는데 노드 간 통신만 안 되는" 상태가 된다.
#                      증상: 웹훅 타임아웃, 다른 노드 파드로 curl 실패
#                      확인: ip -d link show flannel.1 | grep vxlan
#                            → local 192.168.56.x 여야 정상

echo
echo "=== kubectl 설정 ==="
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
echo 'export KUBECONFIG=$HOME/.kube/config' >> /home/vagrant/.bashrc

echo
echo "=== 워커 노드용 토큰 ==="
echo "  아래 값을 k3s-agent.sh 의 K3S_TOKEN 에 넣는다"
echo
cat /var/lib/rancher/k3s/server/node-token
echo
echo "=== 확인 ==="
k3s kubectl get nodes -o wide
