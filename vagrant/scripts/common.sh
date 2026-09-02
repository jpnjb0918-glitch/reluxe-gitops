#!/bin/bash
# ---------------------------------------------------------------------------
# 전 노드 공통 준비 — k3s 설치 "전에" 끝나야 한다
#
# vagrant up 때 자동 실행된다 (Vagrantfile 의 provision).
# ---------------------------------------------------------------------------
set -euo pipefail

echo "=== [1/6] 패키지 설치 ==="
dnf install -y \
  container-selinux \
  selinux-policy-base \
  policycoreutils-python-utils \
  curl tar iproute-tc git

# container-selinux            🔴 없으면 k3s 가 SELinux enforcing 에서 파드를 못 띄운다
# policycoreutils-python-utils    audit2allow · semanage (AVC 거부 분석)
# iproute-tc                      일부 CNI 가 요구
# git                             소스 clone (공유 폴더를 껐으므로)

echo "=== [2/6] swap 비활성 ==="
# 🔴 swap 이 켜져 있으면 kubelet 이 계속 죽는다
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

echo "=== [3/6] 커널 모듈 ==="
cat > /etc/modules-load.d/k8s.conf <<'MOD'
overlay
br_netfilter
MOD
modprobe overlay
modprobe br_netfilter

echo "=== [4/6] sysctl ==="
cat > /etc/sysctl.d/k8s.conf <<'SYS'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
SYS
sysctl --system >/dev/null

echo "=== [5/6] firewalld ==="
# 🔴 학습 목적이면 여기서 끄고 시작한 뒤, 나중에 켜면서 무엇이 막히는지 관찰하는 게 좋다.
#    지금은 필요한 포트만 열어 켜둔 채로 진행한다.
if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-port=6443/tcp    >/dev/null  # API 서버
  firewall-cmd --permanent --add-port=10250/tcp   >/dev/null  # kubelet
  firewall-cmd --permanent --add-port=8472/udp    >/dev/null  # Flannel VXLAN

  # 🔴 파드·서비스 CIDR 을 trusted 에 넣지 않으면 노드 간 파드 통신이 안 된다.
  #    cni0 인터페이스 이름으로 거는 방법은 CNI 설정에 따라 달라져 깨지기 쉽다.
  firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16 >/dev/null
  firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16 >/dev/null

  # NodePort 범위 (레지스트리 30500 · 웹 30080 · MinIO 콘솔 30901)
  firewall-cmd --permanent --add-port=30000-32767/tcp >/dev/null

  firewall-cmd --reload >/dev/null
  echo "  firewalld 규칙 적용 완료"
else
  echo "  firewalld 비활성 — 건너뜀"
fi

echo "=== [6/6] k3s 설정 디렉터리 ==="
# 🔴 registries.yaml 을 넣을 자리를 미리 만든다.
#    k3s 서버는 설치 때 이 디렉터리를 만들지만, 에이전트는 만들지 않는다.
#    없는 상태에서 파일을 복사하면 "No such file or directory" 로 조용히 실패한다.
mkdir -p /etc/rancher/k3s
echo "  /etc/rancher/k3s 준비 완료"

echo
echo "=== 확인 ==="
echo "  SELinux : $(getenforce)      ← Enforcing 이어야 정상"
echo "  Swap    : $(free -h | awk '/Swap/{print $2}')      ← 0 이어야 정상"
echo "  준비 완료: $(hostname)"
