#!/bin/bash
# ===========================================================================
# [node0] Argo CD — GitOps 배포
#
# 무엇이 달라지나
#   기존   Jenkins → kubectl apply → 클러스터        (푸시 방식)
#   지금   Jenkins → git 커밋 ← Argo CD 가 가져감    (풀 방식)
#
#   · Jenkins 가 클러스터를 만지지 않는다 → 권한·kubeconfig 관리가 사라진다
#   · git 커밋 = 배포 이력. 지금 뭐가 떠 있는지 git 이 증명한다
#   · 누가 kubectl 로 손대면 Argo CD 가 되돌린다 (selfHeal)
#   · 롤백이 git revert
# ===========================================================================
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/home/vagrant/.kube/config}
cd ~/reverdi

echo ""
echo "==========================================================="
echo " [6/9] Argo CD (GitOps)"
echo "==========================================================="

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null

# 🔴 node5 에 taint 가 걸려 있다. global 로 넣어야 모든 구성요소에 적용된다.
#    (컨트롤러·서버·repo-server·redis 가 각각 다른 파드다)
# nodePortHttp 30081 — 30080 은 웹 앱이 이미 쓰고 있다.
cat > /tmp/argocd-values.yaml <<'YAML'
global:
  nodeSelector: { workload: infra }
  tolerations:
    - { key: workload, operator: Equal, value: infra, effect: NoSchedule }
configs:
  params: { server.insecure: true }     # 자체서명 인증서라 --insecure
redis-ha: { enabled: false }            # 로컬은 단일로 충분
controller:
  replicas: 1
  resources: { requests: { cpu: 100m, memory: 256Mi }, limits: { cpu: 500m, memory: 512Mi } }
server:
  replicas: 1
  service: { type: NodePort, nodePortHttp: 30081, nodePortHttps: 30443 }
  resources: { requests: { cpu: 50m, memory: 128Mi }, limits: { cpu: 300m, memory: 256Mi } }
repoServer:
  replicas: 1
  resources: { requests: { cpu: 50m, memory: 128Mi }, limits: { cpu: 300m, memory: 512Mi } }
applicationSet: { enabled: false }
notifications:  { enabled: false }
YAML

helm upgrade --install argocd argo/argo-cd -n argocd -f /tmp/argocd-values.yaml --timeout 10m
kubectl wait --for=condition=available --timeout=300s deploy/argocd-server -n argocd

echo ""
echo "--- Application 등록 ---"
echo "    Argo CD 에게 \"이 git 경로를 클러스터에 맞춰라\" 라고 알린다"
kubectl apply -f - <<'YAML' >/dev/null
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: reverdi, namespace: argocd }
spec:
  project: default
  source:
    repoURL: https://github.com/jpnjb0918-glitch/reverdi.git
    targetRevision: main
    path: charts/reverdi
    helm: { valueFiles: [values-vagrant.yaml] }
  destination:
    server: https://kubernetes.default.svc
    namespace: reverdi
  syncPolicy:
    automated:
      prune: true      # git 에서 지운 리소스는 클러스터에서도 삭제
      selfHeal: true   # kubectl 로 손대면 git 상태로 되돌림
    syncOptions: ["CreateNamespace=true"]
    retry: { limit: 5, backoff: { duration: 10s, factor: 2, maxDuration: 3m } }
YAML

sleep 20
kubectl get application -n argocd
echo ""
echo "  ✅ Argo CD 준비 완료 — http://192.168.56.11:30081"
