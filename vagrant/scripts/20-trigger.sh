#!/bin/bash
# ===========================================================================
# [node5 에서 실행 → node0 으로 넘김]
#
# 왜 node5 인가
#   Vagrant 는 정의 순서대로 VM 을 올린다. node5 가 마지막이므로
#   여기까지 왔다는 건 6대가 모두 준비됐다는 뜻이다.
#   하지만 kubectl 은 node0 에만 있으므로, 실제 작업은 node0 에 넘긴다.
#
# 왜 node0 프로비저닝에서 하지 않나
#   node0 은 가장 먼저 실행된다. 그때는 워커가 아직 없어서
#   "6대가 Ready 될 때까지 대기"하면 영원히 끝나지 않는다. (교착)
# ===========================================================================
set -euo pipefail

echo ""
echo "==========================================================="
echo " 전 노드 준비 완료 — 클러스터 구성을 시작합니다"
echo "==========================================================="
echo ""

# sshpass 로 node0 에 접속한다.
# ⚠️ 로컬 검증 전용이다. bento 박스의 vagrant 계정 비밀번호는 vagrant 다.
dnf install -y -q sshpass >/dev/null 2>&1 || \
  dnf install -y -q epel-release >/dev/null 2>&1 && dnf install -y -q sshpass >/dev/null 2>&1

SSH="sshpass -p vagrant ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR vagrant@192.168.56.10"
SCP="sshpass -p vagrant scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# 스크립트를 node0 으로 보낸다 (node5 에도 file provisioner 로 들어와 있다)
$SCP -r /tmp/scripts vagrant@192.168.56.10:/tmp/ >/dev/null

# node0 에서 순서대로 실행한다.
# 각 스크립트는 앞 단계의 결과에 의존하므로 순서를 바꾸면 실패한다.
for s in 21-cluster 30-registry 40-images 50-database 60-app 70-argocd 80-monitoring 90-jenkins 99-summary; do
  $SCP /tmp/scripts/${s}.sh vagrant@192.168.56.10:/tmp/ >/dev/null 2>&1 || true
  $SSH "bash /tmp/scripts/${s}.sh" || {
    echo ""
    echo "  🔴 ${s} 단계에서 실패했습니다."
    echo "     node0 에 접속해 직접 확인하세요:"
    echo "       vagrant ssh node0"
    echo "       bash /tmp/scripts/${s}.sh"
    exit 1
  }
done
