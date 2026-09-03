#!/bin/bash
# ===========================================================================
# [node0] Jenkins — CI
#
# 역할 분담
#   Jenkins   빌드만 한다 (lint → test → 이미지 빌드 → git 커밋)
#   Argo CD   배포만 한다 (git 감지 → 클러스터 반영)
#
#   Jenkins 가 클러스터를 만지지 않으므로 kubeconfig·권한이 필요 없다.
#   AWS 로 가면 EKS 접근 IAM 도 안 줘도 된다.
#
# 빌드 에이전트는 파드로 뜬다.
#   Jenkinsfile 안에 파드 정의가 들어 있어(인라인) UI 설정이 필요 없다.
#   Jenkins 를 다시 깔아도 그대로 동작한다.
# ===========================================================================
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/home/vagrant/.kube/config}

echo ""
echo "==========================================================="
echo " [8/9] Jenkins (CI)"
echo "==========================================================="

helm repo add jenkins https://charts.jenkins.io >/dev/null 2>&1 || true
helm repo update >/dev/null

cat > /tmp/jenkins-values.yaml <<'YAML'
controller:
  nodeSelector: { workload: infra }
  # 🔴 node5 taint 를 견뎌야 컨트롤러가 뜬다
  tolerations:
    - { key: workload, operator: Equal, value: infra, effect: NoSchedule }
  serviceType: NodePort
  nodePort: 30808
  resources:
    requests: { cpu: 500m, memory: 2Gi }
    limits:   { cpu: "2",  memory: 4Gi }
  installPlugins:
    - kubernetes:latest          # 빌드 에이전트를 파드로 띄운다
    - workflow-aggregator:latest # Pipeline
    - git:latest
    - configuration-as-code:latest
  # 초기 설정 마법사를 건너뛴다 (자동화를 위해)
  installLatestPlugins: true

agent:
  # 🔴 true 여야 한다.
  #    false 로 두면 차트가 에이전트 관련 리소스를 아예 만들지 않아
  #    파이프라인이 파드를 띄우지 못한다.
  #    (파드 정의 자체는 Jenkinsfile 안에 있으므로 podTemplates 는 비워둔다)
  enabled: true

persistence:
  enabled: true
  storageClass: local-path
  size: 20Gi

rbac: { create: true }
serviceAccount: { create: true }
YAML

helm upgrade --install jenkins jenkins/jenkins -n infra -f /tmp/jenkins-values.yaml --timeout 15m

echo "--- Jenkins 기동 대기 (플러그인 설치로 3~6분) ---"
kubectl rollout status statefulset/jenkins -n infra --timeout=900s || true

kubectl exec -n infra svc/jenkins -c jenkins -- \
  cat /run/secrets/additional/chart-admin-password 2>/dev/null > ~/.jenkins-admin-password || true

echo ""
kubectl get pod -n infra -o wide | grep jenkins
echo ""
echo "  ✅ Jenkins 준비 완료 — http://192.168.56.11:30808"
