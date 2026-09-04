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
  # -------------------------------------------------------------------------
  # ⚠️ 플러그인 버전을 :latest 로 둔다
  #
  #   장점  항상 최신. 우리가 검증한 시점(2026-09-04)에는 정상 동작했다.
  #   위험  시간이 지나면 다른 조합이 설치된다. 플러그인끼리 의존성이
  #         충돌하면 Jenkins 가 아예 뜨지 않는다.
  #         (jenkinsci/helm-charts 이슈 #219 · #704 · #911 등 반복 보고)
  #
  #   왜 그대로 두나
  #     특정 버전을 박으면 그 버전이 사라지거나 다른 플러그인이
  #     더 높은 버전을 요구할 때 똑같이 깨진다.
  #     운영이라면 플러그인을 미리 구운 커스텀 이미지를 쓰는 것이 맞지만,
  #     학습·시연 환경에서는 과하다.
  #
  #   🔴 Jenkins 가 안 뜨면
  #     kubectl logs -n infra jenkins-0 -c init
  #     → "depends on X, but there is an older version" 이 보이면 의존성 충돌.
  #       그 플러그인을 아래 목록에 명시적으로 추가하거나,
  #       installLatestPlugins: false 로 차트 기본 버전을 쓴다.
  # -------------------------------------------------------------------------
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
