#!/bin/bash
# ===========================================================================
# [node0] k3s 서버 = 컨트롤 플레인
#
# 이 노드에는 워크로드를 올리지 않는다.
# EKS 는 컨트롤 플레인이 VPC 밖 AWS 관리 영역에 있어 애초에 섞이지 않는데,
# 로컬에서는 taint 로 같은 효과를 만든다.
# ===========================================================================
set -euo pipefail

NODE_IP="192.168.56.10"

# 🔴 사설망 인터페이스. Vagrant + VirtualBox 에서는 보통 enp0s8 이다.
#    enp0s3 은 Vagrant NAT(10.0.2.15)로 전 노드가 동일하므로 절대 쓰면 안 된다.
IFACE="enp0s8"

# 🔴 고정 토큰.
#    원래는 서버가 무작위 토큰을 만들고 그걸 에이전트에 알려줘야 하는데,
#    Vagrant 는 VM 사이에 값을 전달할 방법이 없다.
#    미리 정한 값을 양쪽이 쓰면 그 문제가 사라진다.
#    ⚠️ 로컬 검증 전용이다. 운영에서는 절대 이렇게 하지 않는다.
TOKEN="reverdi-local-cluster-token-2026"

echo ""
echo "==========================================================="
echo " [node0] k3s 서버 설치"
echo "==========================================================="
echo ""
echo "  각 옵션의 의미"
echo "   --selinux            enforcing 유지. EKS 노드도 enforcing 이다"
echo "   --disable=traefik    🔴 EKS 에는 없다. 켜두면 Ingress 동작이 달라 헷갈린다"
echo "   --disable=servicelb  마찬가지. AWS 는 ALB 가 담당한다"
echo "   --node-taint         컨트롤 플레인에 워크로드가 안 뜨게 격리"
echo "   --flannel-iface      🔴 필수. 아래 설명 참조"
echo "   --node-ip            쿠버네티스가 보는 노드 주소"
echo ""
echo "  🔴 --node-ip 만으로는 부족한 이유"
echo "     --node-ip 는 \"쿠버네티스가 보는 주소\"만 바꾼다."
echo "     Flannel(CNI)이 VXLAN 터널을 맺을 때 쓰는 인터페이스는 별개라"
echo "     지정하지 않으면 Vagrant NAT(10.0.2.15)를 잡는다."
echo "     그 IP 는 6대가 전부 같아서 터널이 맺히지 않는다."
echo "     증상은 \"파드는 뜨는데 노드 간 통신만 안 됨\" 이라 원인 찾기가 어렵다."
echo "     확인:  ip -d link show flannel.1 | grep vxlan"
echo "            → local 192.168.56.x 여야 정상"
echo ""

curl -sfL https://get.k3s.io | K3S_TOKEN="${TOKEN}" sh -s - server \
  --selinux \
  --disable=traefik \
  --disable=servicelb \
  --node-taint CriticalAddonsOnly=true:NoExecute \
  --flannel-iface="${IFACE}" \
  --node-ip="${NODE_IP}" \
  --advertise-address="${NODE_IP}" \
  --write-kubeconfig-mode 644

# kubectl 을 sudo 없이 쓰게 한다.
# ⚠️ RHEL 계열의 sudo 는 secure_path 에서 /usr/local/bin 을 제외한다.
#    그래서 `sudo k3s` 는 command not found 가 난다. (EKS 노드도 같다)
#    kubeconfig 를 홈에 두면 그 문제를 피할 수 있다.
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
grep -q KUBECONFIG /home/vagrant/.bashrc || \
  echo 'export KUBECONFIG=$HOME/.kube/config' >> /home/vagrant/.bashrc

echo ""
/usr/local/bin/kubectl get nodes -o wide
echo ""
echo "  ✅ 컨트롤 플레인 준비 완료. 이제 워커 노드가 붙는다."
echo ""
