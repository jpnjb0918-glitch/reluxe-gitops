#!/bin/bash
# ===========================================================================
# [node0] 사설 이미지 레지스트리
#
# 왜 필요한가
#   우리가 빌드한 이미지를 파드가 받아갈 곳이 있어야 한다.
#   AWS 에서는 ECR 이 그 역할이고, 로컬에서는 registry:2 를 직접 띄운다.
#
# 🔴 파드를 띄우는 것만으로는 부족하다.
#    각 노드의 containerd 가 "그 주소를 신뢰한다"고 알아야 이미지를 받는다.
#    그 설정이 /etc/rancher/k3s/registries.yaml 이고, kubectl 대상이 아니다.
#    한 대라도 빠지면 그 노드에서만 ImagePullBackOff 가 난다.
# ===========================================================================
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/home/vagrant/.kube/config}

echo ""
echo "==========================================================="
echo " [2/9] 이미지 레지스트리"
echo "==========================================================="

REG="192.168.56.15:30500"

kubectl apply -f - <<'YAML' >/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: registry-data, namespace: infra }
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: local-path
  resources: { requests: { storage: 20Gi } }
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: registry, namespace: infra, labels: { app: registry } }
spec:
  replicas: 1                      # RWO PVC 라 2개 이상 띄우면 안 된다
  selector: { matchLabels: { app: registry } }
  template:
    metadata: { labels: { app: registry } }
    spec:
      nodeSelector: { workload: infra }
      # 🔴 node5 에 taint 가 걸려 있다. nodeSelector 만으로는 못 들어간다.
      tolerations:
        - { key: workload, operator: Equal, value: infra, effect: NoSchedule }
      containers:
        - name: registry
          image: registry:2
          ports: [{ containerPort: 5000 }]
          env:
            - { name: REGISTRY_STORAGE_DELETE_ENABLED, value: "true" }
          volumeMounts: [{ name: data, mountPath: /var/lib/registry }]
      volumes:
        - name: data
          persistentVolumeClaim: { claimName: registry-data }
---
apiVersion: v1
kind: Service
metadata: { name: registry, namespace: infra }
spec:
  type: NodePort
  selector: { app: registry }
  ports: [{ port: 5000, targetPort: 5000, nodePort: 30500 }]
YAML

echo "--- 레지스트리 파드 대기 ---"
kubectl wait --for=condition=available --timeout=300s deploy/registry -n infra
kubectl get pod -n infra -o wide | grep registry

echo ""
echo "--- registries.yaml 을 전 노드에 배포 ---"
echo "    (kubectl 대상이 아니다. 각 노드의 containerd 설정 파일이다)"
CONF="mirrors:
  \"${REG}\":
    endpoint:
      - \"http://${REG}\"
configs:
  \"${REG}\":
    tls:
      insecure_skip_verify: true"
# insecure_skip_verify — 로컬 레지스트리를 HTTP 로 띄웠기 때문이다.
# AWS(ECR)는 HTTPS 라 이 설정이 필요 없다.

echo "$CONF" | sudo tee /etc/rancher/k3s/registries.yaml >/dev/null
sudo systemctl restart k3s
echo "    node0 완료"

for ip in 11 12 13 14 15; do
  ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR vagrant@192.168.56.$ip \
    "sudo mkdir -p /etc/rancher/k3s && echo '$CONF' | sudo tee /etc/rancher/k3s/registries.yaml >/dev/null && sudo systemctl restart k3s-agent"
  echo "    192.168.56.$ip 완료"
done

echo ""
echo "--- 클러스터 복구 대기 ---"
sleep 20
for i in $(seq 1 30); do
  READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo 0)
  [ "$READY" -ge 6 ] && break
  sleep 5
done
kubectl get nodes

echo ""
curl -s "http://${REG}/v2/_catalog" && echo ""
echo "  ✅ 레지스트리 준비 완료 (아직 이미지는 없다)"
