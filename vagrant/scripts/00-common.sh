#!/bin/bash
# ===========================================================================
# [모든 노드] k3s 설치 "전에" 끝나야 하는 준비 작업
#
# 왜 먼저 해야 하나
#   · swap 이 켜져 있으면 kubelet 이 계속 죽는다
#   · container-selinux 가 없으면 SELinux enforcing 에서 파드가 안 뜬다
#   · 커널 모듈·sysctl 이 없으면 파드 간 통신이 안 된다
#   k3s 를 먼저 깔고 나중에 고치면 재시작이 필요해 더 번거롭다.
# ===========================================================================
set -euo pipefail
echo ""
echo "==========================================================="
echo " [$(hostname)] 공통 준비"
echo "==========================================================="

echo "--- [1/5] 패키지 설치 ---"
# container-selinux  🔴 없으면 k3s 가 SELinux enforcing 에서 파드를 못 띄운다.
#                       SELinux 를 끄지 않는 이유 — EKS 워커 노드도 enforcing 이다.
#                       여기서 겪는 문제를 AWS 에서 또 겪지 않으려면 켜둔 채로 배워야 한다.
# iproute-tc         일부 CNI 가 요구
# git                소스 clone (공유 폴더를 껐으므로)
dnf install -y -q \
  container-selinux selinux-policy-base policycoreutils-python-utils \
  curl tar iproute-tc git >/dev/null
echo "    완료"

echo "--- [2/5] swap 비활성 ---"
# 🔴 쿠버네티스는 swap 을 전제로 설계되지 않았다.
#    메모리 압박을 swap 이 흡수해버리면 스케줄러가 잘못된 판단을 한다.
#    kubelet 이 아예 기동을 거부하는 버전도 있다.
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab      # 재부팅 후에도 유지
echo "    완료"

echo "--- [3/5] 커널 모듈 ---"
# overlay        컨테이너 파일시스템(overlayfs)
# br_netfilter   브리지를 지나는 패킷을 iptables 가 볼 수 있게 한다
#                이게 없으면 Service(ClusterIP) 로 가는 트래픽이 사라진다
cat > /etc/modules-load.d/k8s.conf <<'MOD'
overlay
br_netfilter
MOD
modprobe overlay
modprobe br_netfilter
echo "    완료"

echo "--- [4/5] sysctl ---"
# bridge-nf-call-iptables  브리지 트래픽을 iptables 로 넘긴다 (Service 동작에 필수)
# ip_forward               노드가 파드 간 패킷을 전달할 수 있게 한다
cat > /etc/sysctl.d/k8s.conf <<'SYS'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
SYS
sysctl --system >/dev/null
echo "    완료"

echo "--- [5/5] firewalld ---"
# 🔴 firewalld 를 끄지 않는다.
#    AWS 에서는 보안그룹으로 같은 일을 하므로, "무엇을 열어야 하는지"를
#    여기서 익혀두면 그대로 옮겨진다.
if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-port=6443/tcp  >/dev/null   # API 서버
  firewall-cmd --permanent --add-port=10250/tcp >/dev/null   # kubelet (로그·exec)
  firewall-cmd --permanent --add-port=8472/udp  >/dev/null   # 🔴 Flannel VXLAN
  #   8472/udp 가 막히면 "파드는 뜨는데 노드 간 통신만 안 되는" 상태가 된다.
  #   증상이 표면적 원인을 안 가리켜서 찾기 가장 어려운 유형이다.

  # 🔴 파드·서비스 CIDR 을 trusted 에 넣지 않으면 노드 간 파드 통신이 안 된다.
  #    cni0 인터페이스 이름으로 거는 방법은 CNI 설정에 따라 달라져 깨지기 쉽다.
  firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16 >/dev/null  # 파드
  firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16 >/dev/null  # 서비스

  firewall-cmd --permanent --add-port=30000-32767/tcp >/dev/null  # NodePort 범위
  firewall-cmd --reload >/dev/null
  echo "    규칙 적용 완료"
else
  echo "    firewalld 비활성 — 건너뜀"
fi

# 🔴 registries.yaml 을 넣을 자리를 미리 만든다.
#    k3s 서버는 설치 때 이 디렉터리를 만들지만 에이전트는 만들지 않는다.
#    없는 상태에서 파일을 복사하면 "No such file or directory" 로 조용히 실패한다.
mkdir -p /etc/rancher/k3s

echo ""
echo "  SELinux : $(getenforce)   ← Enforcing 이 정상 (EKS 와 같은 조건)"
echo "  Swap    : $(free -h | awk '/Swap/{print $2}')          ← 0 이어야 정상"
echo ""
