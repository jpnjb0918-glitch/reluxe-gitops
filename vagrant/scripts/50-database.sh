#!/bin/bash
# ===========================================================================
# [node0] PostgreSQL 고가용성 (CloudNativePG)
#
# 왜 이렇게 하나
#   AWS 에서는 RDS Multi-AZ 를 쓴다. 로컬에는 그런 관리형 서비스가 없으므로
#   CloudNativePG 오퍼레이터로 같은 모양을 만든다.
#
#   CNPG 가 만드는 접속 주소가 RDS 와 형태가 같다.
#     로컬  reverdi-db-rw (쓰기) / reverdi-db-ro (읽기)
#     AWS   ...-primary  (쓰기) / ...-ro         (읽기)
#   그래서 여기서 검증한 앱의 읽기/쓰기 분리가 AWS 에서 그대로 통한다.
#
# 🔴 순서가 중요하다 — 실제로 겪은 문제다.
#    "Secret 을 먼저 만들고 DB 를 만든다" 로 하면 실패한다.
#    CNPG 가 초기화할 때 Secret 을 새로 만들어 덮어쓰기 때문이다.
#    반드시 DB 를 먼저 만들고, CNPG 가 만든 비밀번호를 꺼내 써야 한다.
# ===========================================================================
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/home/vagrant/.kube/config}

echo ""
echo "==========================================================="
echo " [4/9] 데이터베이스 (고가용성 3대)"
echo "==========================================================="

command -v helm >/dev/null || \
  curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null

echo "--- CloudNativePG 오퍼레이터 ---"
echo "    오퍼레이터가 없으면 Cluster 라는 리소스 종류 자체를 클러스터가 모른다"
helm repo add cnpg https://cloudnative-pg.github.io/charts >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace \
  --wait --timeout 10m >/dev/null
kubectl wait --for=condition=available --timeout=300s deploy -l app.kubernetes.io/name=cloudnative-pg -n cnpg-system
echo "    준비 완료"

echo ""
echo "--- DB 클러스터 생성 (primary 1 + replica 2) ---"
kubectl apply -f - <<'YAML' >/dev/null
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata: { name: reverdi-db, namespace: reverdi }
spec:
  instances: 3                                     # node1~3 에 하나씩
  imageName: ghcr.io/cloudnative-pg/postgresql:17.2   # AWS RDS PG17 과 맞춘다
  primaryUpdateStrategy: unsupervised
  storage: { size: 10Gi, storageClass: local-path }
  bootstrap:
    initdb: { database: reverdi, owner: reverdi }
  affinity:
    nodeSelector: { workload: web }
    # primary 와 replica 가 다른 노드에 뜨게 한다.
    # 같은 노드에 몰리면 그 노드가 죽을 때 전부 사라져 페일오버가 의미 없다.
    podAntiAffinityType: preferred
    topologyKey: kubernetes.io/hostname
  resources:
    requests: { cpu: 200m, memory: 512Mi }
    limits:   { cpu: "1",  memory: 1Gi }
YAML

echo "    3대가 뜰 때까지 대기 (2~4분)"
for i in $(seq 1 90); do
  ST=$(kubectl get cluster reverdi-db -n reverdi -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  RD=$(kubectl get cluster reverdi-db -n reverdi -o jsonpath='{.status.readyInstances}' 2>/dev/null || echo 0)
  echo "    ${RD}/3  ${ST}"
  [ "$RD" = "3" ] && break
  sleep 10
done
kubectl get cluster,pod -n reverdi -o wide

echo ""
echo "--- 🔴 CNPG 가 만든 비밀번호를 꺼낸다 ---"
echo "    (우리가 미리 만든 Secret 은 CNPG 가 덮어쓰므로 이 순서여야 한다)"
PW=$(kubectl get secret reverdi-db-app -n reverdi -o jsonpath='{.data.password}' | base64 -d)

echo ""
echo "--- 앱 Secret 생성 ---"
# 🔴 SESSION_SECRET 을 반드시 주입해야 한다.
#    미설정이면 앱이 파드마다 랜덤 값을 만든다. 파드가 3개면 서로의 쿠키를
#    인정하지 않아 로그인이 아예 동작하지 않는다. 보안 이전에 기능 문제다.
kubectl delete secret reverdi-secret -n reverdi >/dev/null 2>&1 || true
kubectl create secret generic reverdi-secret -n reverdi \
  --from-literal=DATABASE_URL="postgresql+asyncpg://reverdi:${PW}@reverdi-db-rw.reverdi.svc:5432/reverdi" \
  --from-literal=DATABASE_RO_URL="postgresql+asyncpg://reverdi:${PW}@reverdi-db-ro.reverdi.svc:5432/reverdi" \
  --from-literal=SESSION_SECRET="$(openssl rand -hex 32)" \
  --from-literal=ADMIN_USERNAME=admin \
  --from-literal=ADMIN_PASSWORD="$(openssl rand -hex 12)" \
  --from-literal=CLIENT_USERNAME=client \
  --from-literal=CLIENT_PASSWORD="$(openssl rand -hex 12)" >/dev/null

kubectl get svc -n reverdi
echo ""
echo "  ✅ DB 준비 완료 — 쓰기는 -rw, 읽기는 -ro 로 나뉜다"
