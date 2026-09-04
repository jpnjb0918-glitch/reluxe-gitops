# Reverdi 로컬 검증 클러스터 — 전자동 구축

> `vagrant up` 한 번으로 VM 6대에 쿠버네티스 클러스터와 앱·CI/CD·모니터링까지 올립니다.
>
> **✅ 검증 완료** — 2026-09-04 처음부터 다시 돌려 약 90분 만에 성공

---

## 1. 사전 준비 (한 번만)

### 필요한 것

| | 확인 |
|---|---|
| **VirtualBox** | `VBoxManage --version` |
| **Vagrant** | `vagrant --version` |
| **호스트 RAM** | **48GB 이상 권장** (VM 이 40GB 를 씁니다) |
| 디스크 여유 | 300GB |

설치 후 **PowerShell 을 새로 열어야** PATH 가 반영됩니다.

### 플러그인

```powershell
vagrant plugin install vagrant-disksize
```

node4(60GB)·node5(100GB)는 기본 박스 용량으로 부족합니다.

> ⚠️ **Hyper-V 와 충돌할 수 있습니다.** WSL2 나 Docker Desktop 을 쓰고 있다면
> VirtualBox 7.1 이상을 쓰세요.

---

## 2. 실행

```powershell
cd vagrant
vagrant up
```

**80~110분** 걸립니다. 대부분 이미지 다운로드와 크롤러 빌드(2.7GB) 시간입니다.

화면에 각 단계가 "무엇을 왜 하는지" 설명하며 진행됩니다.
**마지막에 접속 주소와 비밀번호가 한 번에 출력됩니다.**

---

## 3. 무엇이 만들어지나

```
node0  192.168.56.10   컨트롤 플레인 전용 (taint 로 워크로드 격리)
node1  192.168.56.11   웹 파드 + DB 파드
node2  192.168.56.12   웹 파드 + DB 파드
node3  192.168.56.13   웹 파드 + DB 파드
node4  192.168.56.14   크롤러 · 이미지 빌드
node5  192.168.56.15   레지스트리 · Jenkins · Argo CD · 모니터링
```

| 구성요소 | 역할 |
|---|---|
| **k3s** | 쿠버네티스 (EKS 대응) |
| **Docker Registry** | 이미지 저장소 (ECR 대응) |
| **CloudNativePG** | PostgreSQL 고가용성 3대 (RDS Multi-AZ 대응) |
| **Reverdi 앱** | 웹 파드 3개 · 크롤러 CronJob |
| **Argo CD** | GitOps 배포 |
| **Jenkins** | CI (빌드) |
| **Prometheus + Grafana** | 모니터링 |

---

## 4. 진행 순서와 이유

| 단계 | 하는 일 | 왜 이 순서인가 |
|:--:|---|---|
| 0 | 공통 준비 | swap·커널·방화벽은 k3s **설치 전에** 끝나야 함 |
| 1 | k3s 서버 | 워커가 붙을 대상 |
| 2 | k3s 에이전트 ×5 | 서버가 떠 있어야 함 |
| 3 | taint · 네임스페이스 | 6대가 전부 Ready 여야 가능 |
| 4 | 레지스트리 | 이미지를 올릴 곳이 먼저 있어야 함 |
| 5 | 이미지 빌드 | 레지스트리에 push 해야 함 |
| 6 | **DB → Secret** | 🔴 순서 중요 (아래 참조) |
| 7 | 앱 배포 | 이미지와 DB 가 있어야 함 |
| 8 | Argo CD | |
| 9 | 모니터링 | 앱이 떠 있어야 지표 수집 |
| 10 | Jenkins | |

### 🔴 6번 순서가 중요한 이유

```
잘못  Secret 생성 → DB 생성          ← CNPG 가 Secret 을 덮어써서 실패
맞음  DB 생성 → CNPG 비번 꺼내기 → Secret 생성
```

`bootstrap.initdb.secret` 을 명시해도 **CloudNativePG 가 초기화 시점에
Secret 을 새로 만듭니다.** 실제로 겪은 문제라 스크립트에 반영해뒀습니다.

---

## 5. 끝나면

### 접속 정보

마지막 화면에 전부 출력됩니다. 놓쳤으면:

```powershell
vagrant ssh node0 -c "bash /tmp/scripts/99-summary.sh"
```

### 포트

| 포트 | 서비스 |
|---|---|
| 30080 | 웹 앱 |
| 30081 | Argo CD |
| 30300 | Grafana |
| 30500 | 레지스트리 |
| 30808 | Jenkins |

`.11` ~ `.15` 아무 IP 로나 접속됩니다. NodePort 는 어느 노드로 들어와도 됩니다.

### 비밀번호는 매번 새로 만들어집니다

파일에 적어두지 않습니다. 필요할 때 꺼내 쓰세요.

```bash
vagrant ssh node0
```

```bash
# 웹 앱
kubectl get secret reverdi-secret -n reverdi -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d ; echo

# DB
kubectl get secret reverdi-db-app -n reverdi -o jsonpath='{.data.password}' | base64 -d ; echo

# Grafana
kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d ; echo

# Argo CD
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d ; echo

# Jenkins
kubectl exec -n infra svc/jenkins -c jenkins -- cat /run/secrets/additional/chart-admin-password ; echo
```

---

## 6. 🔴 자동화하지 못한 것

**Jenkins 파이프라인**에는 GitHub 토큰이 필요합니다. 개인 자격증명이라
스크립트에 넣을 수 없습니다.

### 토큰 발급

`github.com` → Settings → Developer settings → Personal access tokens
→ **Tokens (classic)** → Generate new token → 🔴 **`repo` 체크** → 생성

`ghp_...` 값을 복사하세요. **한 번만 보입니다.**

### Jenkins 에 등록

`http://192.168.56.11:30808` → Jenkins 관리 → Credentials → System → Global

| | |
|---|---|
| Kind | Username with password |
| Username | GitHub 아이디 |
| Password | 토큰 |
| **ID** | 🔴 **`gitops-push-token`** |

> ID 가 다르면 파이프라인 마지막 단계에서 실패합니다. Jenkinsfile 이 이 이름으로 찾습니다.

### 파이프라인 생성

새로운 Item → `reverdi-ci` → **Pipeline**

| | |
|---|---|
| Definition | Pipeline script from SCM |
| SCM | Git |
| URL | `https://github.com/epqlffltm/CloudeDX.git` |
| Branch | `*/main` |
| Script Path | `Jenkinsfile` |

첫 빌드는 15~25분 걸립니다.

---

## 7. 확인해볼 것

### 파드 분산

```bash
kubectl get pod -n reverdi -o wide
```

웹 3개와 DB 3개가 **node1·2·3 에 하나씩**이면 정상입니다.
`topologySpreadConstraints` + `matchLabelKeys` 가 동작한 결과입니다.

### DB 페일오버 (발표 시연용)

터미널 2개를 엽니다.

**창1 — 조회를 계속 때린다**
```bash
while true; do printf '%s  ' "$(date +%H:%M:%S)"; \
  curl -s -o /dev/null -w "%{http_code}\n" -m 3 http://192.168.56.11:30080/; sleep 1; done
```

**창2 — primary 를 죽인다**
```bash
kubectl get cluster -n reverdi
kubectl delete pod -n reverdi reverdi-db-1
kubectl get cluster -n reverdi
```

창1 의 **200 이 끊기지 않으면서** PRIMARY 가 바뀝니다.
읽기는 replica 로 가기 때문입니다. **AWS RDS Multi-AZ 와 같은 동작**입니다.

### Argo CD self-heal

```bash
kubectl scale deploy reverdi-web -n reverdi --replicas=1
kubectl get pod -n reverdi -w
```

손으로 1개로 줄여도 **Argo CD 가 3개로 되돌립니다.** git 에 적힌 것이 정답이기 때문입니다.

### 크롤러

```bash
kubectl create job -n reverdi --from=cronjob/reverdi-crawler crawl-1
kubectl logs -n reverdi -l job-name=crawl-1 -f
```

node4 에서만 돕니다 (taint 로 격리).

### Grafana 에서 앱 지표

`Explore` → Prometheus → **Code** 모드

```
http_requests_total
sum(rate(http_requests_total[1m])) by (status)
```

---

## 8. VM 관리

```powershell
vagrant halt          # 작업 끝나면 정지 (RAM 40GB 를 잡고 있습니다)
vagrant up            # 다시 시작 — 클러스터는 그대로 복구됩니다
vagrant ssh node0     # 접속 (kubectl · helm 은 여기서)
vagrant status
vagrant destroy -f    # 전부 삭제하고 처음부터
```

---

## 9. 막히면

### 특정 단계만 다시 실행

각 스크립트는 독립적으로 다시 돌릴 수 있습니다.

```bash
vagrant ssh node0
bash /tmp/scripts/60-app.sh        # 앱만 다시 배포
bash /tmp/scripts/99-summary.sh    # 접속 정보 다시 보기
```

### 자주 막히는 곳

| 증상 | 원인 | 조치 |
|---|---|---|
| 박스 다운로드 404 | Rocky 가 Vault 로 이전 | Vagrantfile 이 `bento` 사용 중 |
| `Timed out while waiting for the machine to boot` | 첫 부팅이 오래 걸림 | `vagrant reload <노드>` |
| 노드 간 파드 통신 안 됨 | Flannel 이 NAT 인터페이스 선택 | `ip -d link show flannel.1` → `local 192.168.56.x` 확인 |
| 파드가 `Pending` | taint 에 toleration 없음 | `kubectl describe pod` |
| `ImagePullBackOff` | `registries.yaml` 미배포 | `bash /tmp/scripts/30-registry.sh` |
| `CreateContainerConfigError` | Secret 없음 | `bash /tmp/scripts/50-database.sh` |
| 파드가 영원히 `Ready` 안 됨 | DB 없음 (`/ready` 가 DB 확인) | DB 먼저 |

### 전체 로그

```powershell
vagrant up 2>&1 | Tee-Object -FilePath build.log
```

나중에 `build.log` 로 어디서 막혔는지 볼 수 있습니다.

---

## 10. AWS 로 이어지는 것

### 그대로 가는 것

- Helm 차트 `templates/` 전부
- taint · toleration · nodeSelector
- `topologySpreadConstraints` (키만 호스트명 → AZ)
- probe · PDB · rollingUpdate
- 읽기/쓰기 분리 (`-rw`/`-ro` → RDS writer/reader)

### 버려지는 것

| 로컬 | AWS |
|---|---|
| Docker Registry | ECR |
| CloudNativePG | RDS Multi-AZ |
| MinIO | S3 |
| NodePort | ALB Ingress |

**매니페스트는 버려지지만, 그것으로 검증한 앱 설정과 운영 감각은 남습니다.**

### 환경 전환

```bash
helm upgrade --install reverdi charts/reverdi -f values-vagrant.yaml   # 로컬
helm upgrade --install reverdi charts/reverdi -f values-aws.yaml       # AWS
```

**값 파일 하나만 바꾸면 됩니다.**
