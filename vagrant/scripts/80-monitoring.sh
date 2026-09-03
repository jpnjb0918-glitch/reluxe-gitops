#!/bin/bash
# ===========================================================================
# [node0] Prometheus + Grafana
#
# 경보 철학 — 구성도 4페이지
#   CPU 80% 로 깨우지 않는다. "사용자가 겪는 실패"를 기준으로 본다.
#     원인 기반 ❌  CPU 80% · 메모리 90%
#     증상 기반 ✅  요청 실패율 1% · p95 500ms · HPA 가 max 에 붙음
#
# 🔴 node-exporter 의 toleration 이 특별하다
#    DaemonSet 이라 전 노드에 떠야 하는데, node0(컨트롤)·node4·node5 에
#    각각 다른 taint 가 걸려 있다. operator: Exists 로 전부 견디게 한다.
# ===========================================================================
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/home/vagrant/.kube/config}

echo ""
echo "==========================================================="
echo " [7/9] 모니터링 (Prometheus · Grafana)"
echo "==========================================================="

# 🔴 Grafana admin 비밀번호를 값 파일에 적지 않는다.
#    Secret 을 미리 만들고 참조만 한다.
GPW=$(openssl rand -hex 12)
kubectl delete secret grafana-admin -n monitoring >/dev/null 2>&1 || true
kubectl create secret generic grafana-admin -n monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$GPW" >/dev/null

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

cat > /tmp/kps-values.yaml <<'YAML'
prometheus:
  prometheusSpec:
    nodeSelector: { workload: infra }
    tolerations:
      - { key: workload, operator: Equal, value: infra, effect: NoSchedule }
    retention: 7d                       # 로컬은 7일이면 충분
    resources: { requests: { cpu: 200m, memory: 1Gi }, limits: { cpu: "1", memory: 2Gi } }
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          accessModes: ["ReadWriteOnce"]
          resources: { requests: { storage: 10Gi } }

alertmanager: { enabled: false }        # 테스트 단계라 알림 연동 전

grafana:
  nodeSelector: { workload: infra }
  tolerations:
    - { key: workload, operator: Equal, value: infra, effect: NoSchedule }
  persistence: { enabled: true, storageClassName: local-path, size: 5Gi }
  resources: { requests: { cpu: 100m, memory: 256Mi }, limits: { cpu: 500m, memory: 512Mi } }
  admin:
    existingSecret: grafana-admin       # 위에서 만든 Secret 참조
    userKey: admin-user
    passwordKey: admin-password
  service: { type: NodePort, nodePort: 30300 }

# 🔴 전 노드 지표 수집. taint 걸린 노드에도 떠야 하므로 전부 허용한다.
nodeExporter:
  enabled: true
  tolerations:
    - { operator: Exists }

kubeStateMetrics: { enabled: true }
# k3s 는 컨트롤 플레인 구성요소를 한 프로세스로 돌려 개별 수집이 안 된다
kubeControllerManager: { enabled: false }
kubeScheduler:         { enabled: false }
kubeEtcd:              { enabled: false }
kubeProxy:             { enabled: false }
YAML

helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  -n monitoring -f /tmp/kps-values.yaml --timeout 15m

echo ""
echo "--- 🔴 앱 지표 수집 등록 (ServiceMonitor) ---"
echo "    이게 없으면 노드·컨테이너 지표만 보이고"
echo "    \"요청 수·지연·에러율\" 같은 사용자 관점 지표는 못 본다"
kubectl apply -f - <<'YAML' >/dev/null
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: reverdi-web
  namespace: monitoring
  labels: { release: kps }      # Prometheus 가 이 라벨로 ServiceMonitor 를 찾는다
spec:
  namespaceSelector: { matchNames: [reverdi] }
  selector:
    matchLabels:
      app.kubernetes.io/name: reverdi
      app.kubernetes.io/component: web
  endpoints:
    - { port: http, path: /metrics, interval: 30s }
YAML

# 지표가 쌓이도록 트래픽을 조금 만든다
for i in $(seq 1 30); do curl -s -o /dev/null http://192.168.56.11:30080/ || true; done

echo "$GPW" > ~/.grafana-admin-password
echo ""
kubectl get pod -n monitoring -o wide | head -12
echo ""
echo "  ✅ 모니터링 준비 완료 — http://192.168.56.11:30300"
