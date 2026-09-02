# Vagrant 클러스터 — 처음부터 끝까지

> Rocky Linux 9 · k3s · VM 6대
> **아무것도 안 깔린 상태**에서 앱이 뜰 때까지의 전 과정입니다.

---

## 0. 전체 그림 — 무엇이 어디로 가나

```
[내 PC (Windows)]
  Vagrant + VirtualBox
     └─ VM 6대를 만든다
     └─ helm.exe 는 차트 문법 검사용 (클러스터 접속은 VM 안에서)

[저장소 2개]
  CloudeDX          앱 소스 · Dockerfile     → node4 에서 clone (이미지 빌드용)
  reluxe-gitops     차트 · infra · argocd    → node0 에서 clone (배포용)

[VM 6대]
  node0   컨트롤 플레인          ← kubectl · helm 명령을 여기서 친다
  node1~3 웹 파드 + DB 파드
  node4   크롤러 · 이미지 빌드    ← 소스를 받아 이미지를 만든다
  node5   레지스트리 · MinIO · Jenkins · Argo CD
```

### 🔴 저장소가 왜 둘인가

| 저장소 | 담는 것 | 누가 커밋 |
|---|---|---|
| **CloudeDX** | `app/` · `dockerfile.*` · `Jenkinsfile` | 개발자 |
| **reluxe-gitops** | `charts/` · `infra/` · `argocd/` · `helm-values/` | Jenkins (이미지 태그만) |

같은 저장소에 두면 **무한 루프**가 납니다.
Jenkins 가 빌드 → 태그 커밋 → 그 커밋이 Jenkins 를 다시 깨움 → 반복.

---

## 1. 내 PC 준비 (Windows)

### 1-1. VirtualBox

`https://www.virtualbox.org/wiki/Downloads` → Windows hosts

> ⚠️ **Hyper-V 와 충돌할 수 있습니다.** WSL2 나 Docker Desktop 을 쓰고 있다면
> VirtualBox 7.1 이상을 쓰세요. 그래도 VM 이 안 뜨면 관리자 PowerShell 에서:
> ```powershell
> bcdedit /enum | findstr hypervisorlaunchtype
> ```
> `Off` 로 바꾸면 VirtualBox 는 되지만 **WSL2·Docker Desktop 이 함께 죽습니다.**

### 1-2. Vagrant

`https://developer.hashicorp.com/vagrant/downloads` → Windows AMD64

설치 후 **PowerShell 을 새로 열어야** PATH 가 반영됩니다.

```powershell
vagrant --version
VBoxManage --version
```

### 1-3. 디스크 플러그인

```powershell
vagrant plugin install vagrant-disksize
```

**node4(60GB)·node5(100GB)는 기본 박스 용량으로 부족합니다.**

### 1-4. (선택) helm.exe

차트 문법을 내 PC 에서 검사할 때만 필요합니다.
`https://get.helm.sh/helm-v3.16.3-windows-amd64.zip` → `helm.exe` 하나만 꺼내 씁니다.

> 클러스터 접속은 VM 안에서 하므로 없어도 진행됩니다.

---

## 2. VM 6대 만들기

```powershell
cd D:\project\Reluxe\vagrant
vagrant up
```

**30~60분** 걸립니다. 박스 다운로드 + `dnf install` 포함입니다.

한 대씩 확인하며 올리려면:

```powershell
vagrant up node0
vagrant status
```

### ⚠️ 박스 다운로드가 404 로 실패하면

```
An error occurred while downloading the remote file.
The requested URL returned error: 404
```

**Rocky 공식 박스(`rockylinux/9`)에서 반복되는 문제**입니다.
마이너 버전이 Vault 로 옮겨질 때 Vagrant 레지스트리 경로가 갱신되지 않아 생깁니다.

Vagrantfile 은 이미 **`bento/rockylinux-9`**(Chef 관리, 링크 안정적)를 쓰고 있습니다.
그래도 안 되면 Vagrantfile 안의 주석에 대안 두 가지가 있습니다.

```powershell
# 캐시가 꼬였으면 지우고 다시
vagrant box list
vagrant box remove rockylinux/9 --all
vagrant up
```

### ⚠️ `Timed out while waiting for the machine to boot`

첫 부팅이 기본 300초 안에 안 끝난 겁니다. **파일이 잘못된 게 아닙니다.**

특히 **node5** 는 RAM 16GB + 디스크 100GB 리사이즈가 겹쳐 오래 걸립니다.
Vagrantfile 에 `boot_timeout = 900` 을 넣어뒀지만, 그래도 걸리면 더 늘리세요.

**먼저 실제로 부팅 중인지 확인**

VirtualBox 관리자에서 해당 VM 창을 열어보세요.
로그인 프롬프트가 떠 있으면 **부팅은 됐고 Vagrant 만 기다리다 포기한** 것입니다.

```powershell
vagrant status              # 어느 VM 이 running 인지
vagrant reload node5        # 그 VM 만 다시
vagrant provision node5     # 프로비저닝만 다시 (부팅은 됐을 때)
```

**호스트가 버거우면 한 대씩**

6대를 한 번에 올리면 디스크 I/O 가 몰립니다.

```powershell
vagrant up node0
vagrant up node1
vagrant up node2
vagrant up node3
vagrant up node4
vagrant up node5
```

느려도 이 편이 확실합니다. 특히 **node4·node5 는 디스크가 커서** 따로 올리는 게 낫습니다.

### 정상 신호

각 VM 프로비저닝 마지막에 이렇게 나옵니다.

```
SELinux : Enforcing      ← 이게 맞습니다. 끄지 않습니다
Swap    : 0B             ← 0 이어야 kubelet 이 안 죽습니다
준비 완료: node0
```

### VM 관리

```powershell
vagrant status              # 6대 상태
vagrant halt                # 전체 정지 (작업 끝날 때)
vagrant up                  # 다시 시작
vagrant reload node1        # 한 대만 재부팅
vagrant destroy -f          # 전부 삭제 (처음부터 다시)
```

> 💡 **작업이 끝나면 `vagrant halt`.** 6대가 RAM 40GB 를 잡고 있습니다.

---

## 3. SSH 접속

### 3-1. 기본

```powershell
vagrant ssh node0
```

비밀번호가 필요 없습니다. Vagrant 가 키를 자동 관리합니다. 나올 때는 `exit`.

### 3-2. VM 끼리

```bash
# node0 안에서
ssh vagrant@192.168.56.11      # 비밀번호: vagrant
```

### 3-3. 🔴 파일을 VM 으로 옮기는 법

**공유 폴더를 껐습니다.** Rocky 공식 박스에 Guest Additions 가 없어서,
켜두면 `vagrant up` 이 `mount.vboxsf: No such device` 로 멈춥니다.

**① git clone (권장)**

```bash
vagrant ssh node4
git clone https://github.com/epqlffltm/CloudeDX.git
```

가장 깔끔합니다. VM 은 NAT 로 인터넷에 나갑니다.

**② 표준입력으로 밀어넣기**

```powershell
Get-Content scripts\k3s-server.sh | vagrant ssh node0 -c "cat > /tmp/k3s-server.sh"
vagrant ssh node0 -c "sudo bash /tmp/k3s-server.sh"
```

**③ 붙여넣기**

```bash
vagrant ssh node0
cat > /tmp/setup.sh <<'EOF'
(내용 붙여넣기)
EOF
sudo bash /tmp/setup.sh
```

> ⚠️ 한글 주석이 든 스크립트는 터미널 인코딩 때문에 깨질 수 있습니다. 그럴 땐 ①번을 쓰세요.

---

## 4. k3s 설치

### 4-1. node0 — 서버

```powershell
Get-Content scripts\k3s-server.sh | vagrant ssh node0 -c "cat > /tmp/k3s-server.sh"
vagrant ssh node0 -c "sudo bash /tmp/k3s-server.sh"
```

마지막에 **토큰**이 나옵니다. 복사해두세요.

```
K10abc123def456...::server:xxxxxxxx
```

### 4-2. node1~5 — 에이전트

**IP 와 라벨이 각각 다릅니다.**

```powershell
$T = "여기에_토큰_붙여넣기"

Get-Content scripts\k3s-agent.sh | vagrant ssh node1 -c "cat > /tmp/a.sh"
vagrant ssh node1 -c "sudo bash /tmp/a.sh 192.168.56.11 web '$T'"

Get-Content scripts\k3s-agent.sh | vagrant ssh node2 -c "cat > /tmp/a.sh"
vagrant ssh node2 -c "sudo bash /tmp/a.sh 192.168.56.12 web '$T'"

Get-Content scripts\k3s-agent.sh | vagrant ssh node3 -c "cat > /tmp/a.sh"
vagrant ssh node3 -c "sudo bash /tmp/a.sh 192.168.56.13 web '$T'"

Get-Content scripts\k3s-agent.sh | vagrant ssh node4 -c "cat > /tmp/a.sh"
vagrant ssh node4 -c "sudo bash /tmp/a.sh 192.168.56.14 batch '$T'"

Get-Content scripts\k3s-agent.sh | vagrant ssh node5 -c "cat > /tmp/a.sh"
vagrant ssh node5 -c "sudo bash /tmp/a.sh 192.168.56.15 infra '$T'"
```

### 4-3. 확인

```bash
vagrant ssh node0
kubectl get nodes -o wide
```

**6대가 `Ready`** 이고 **INTERNAL-IP 가 각자 다른지** 봅니다.

```
NAME    STATUS   INTERNAL-IP
node0   Ready    192.168.56.10
node1   Ready    192.168.56.11
...
```

> 🔴 전부 `10.0.2.15` 로 같으면 `--node-ip` 가 안 먹은 겁니다.
> Vagrant 의 NAT 인터페이스를 잡은 거라 노드 간 통신이 깨집니다. 재설치하세요.

---

## 5. taint · 네임스페이스

**node0 에서** 실행합니다.

```powershell
Get-Content scripts\setup-cluster.sh | vagrant ssh node0 -c "cat > /tmp/s.sh"
vagrant ssh node0 -c "sudo bash /tmp/s.sh"
```

라벨 보정 → taint → 네임스페이스 4개(`reluxe`·`infra`·`argocd`·`monitoring`)를 만듭니다.

> 🔴 **taint 를 빼먹으면 안 됩니다.** label 만으로는 다른 파드가
> 배치·인프라 노드로 새어 들어오는 걸 막지 못합니다.

---

## 6. 배포용 저장소 clone (node0)

```bash
vagrant ssh node0
git clone https://github.com/jpnjb0918-glitch/reluxe-gitops.git
cd reluxe-gitops
ls
# argocd  charts  helm-values  infra
```

**앞으로의 kubectl · helm 명령은 전부 이 디렉터리에서** 칩니다.

> 💡 내 PC 에서 파일을 고쳤으면 `git pull` 로 받아오세요.
> VM 안에서 직접 고치면 다시 커밋하기 번거롭습니다.

---

## 7. 레지스트리

```bash
kubectl apply -f infra/registry.yaml
kubectl get pod -n infra -w      # Running 될 때까지
```

파드가 뜨면 **전 노드에 접속 설정을 배포**합니다.

```powershell
# PowerShell — vagrant 디렉터리에서
foreach ($n in "node0","node1","node2","node3","node4","node5") {
  Get-Content ..\infra\registries.yaml | vagrant ssh $n -c "sudo tee /etc/rancher/k3s/registries.yaml > /dev/null"
  if ($n -eq "node0") { vagrant ssh $n -c "sudo systemctl restart k3s" }
  else                { vagrant ssh $n -c "sudo systemctl restart k3s-agent" }
  Write-Host "$n 완료"
}
```

> 🔴 `registries.yaml` 은 **kubectl 대상이 아닙니다.**
> 쿠버네티스 리소스가 아니라 k3s(containerd)의 노드 설정 파일입니다.
> 한 대라도 빠지면 **그 노드에서만** `ImagePullBackOff` 가 납니다.

**확인**

```bash
curl http://192.168.56.15:30500/v2/_catalog
# {"repositories":[]}
```

---

## 8. DB (CloudNativePG)

**오퍼레이터를 먼저** 깔아야 합니다. 없으면 `Cluster` 리소스를 못 알아듣습니다.

```bash
# node0 에 helm 설치
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace

# 오퍼레이터가 Running 이 된 뒤에
kubectl apply -f infra/postgres-cluster.yaml
kubectl get cluster -n reluxe -w
```

`instances: 3` 이 전부 뜨면 됩니다. **primary 1 + replica 2** 입니다.

```bash
kubectl get pod -n reluxe -o wide     # node1~3 에 흩어졌는지
```

---

## 9. 🔴 앱 Secret 만들기

**차트는 Secret 을 만들지 않습니다. 참조만 합니다.**

```bash
# CloudNativePG 가 만든 DB 비밀번호를 꺼낸다
PW=$(kubectl get secret reluxe-db-app -n reluxe -o jsonpath='{.data.password}' | base64 -d)
echo "DB 비밀번호: $PW"

kubectl create secret generic reluxe-secret -n reluxe \
  --from-literal=DATABASE_URL="postgresql+asyncpg://reluxe:${PW}@reluxe-db-rw.reluxe.svc:5432/reluxe" \
  --from-literal=DATABASE_RO_URL="postgresql+asyncpg://reluxe:${PW}@reluxe-db-ro.reluxe.svc:5432/reluxe" \
  --from-literal=SESSION_SECRET="$(python3 -c 'import secrets;print(secrets.token_hex(32))')" \
  --from-literal=ADMIN_USERNAME=admin \
  --from-literal=ADMIN_PASSWORD="$(openssl rand -hex 12)" \
  --from-literal=CLIENT_USERNAME=client \
  --from-literal=CLIENT_PASSWORD="$(openssl rand -hex 12)"
```

### 왜 이게 중요한가

**`SESSION_SECRET` 이 없으면 로그인이 동작하지 않습니다.**

`app/config.py` 는 미설정 시 `secrets.token_hex(32)` 로 **파드마다 다른 랜덤 값**을 만듭니다.
replicas 3 이면 세 파드가 서로의 쿠키를 인정하지 않습니다.

**`-rw` / `-ro` 로 나뉜 이유**

CloudNativePG 가 두 서비스를 자동으로 만듭니다.
쓰기는 primary(`-rw`), 읽기는 replica(`-ro`) 로 갑니다.
**RDS 의 writer/reader 엔드포인트와 같은 모양**이라, 여기서 검증한 게 AWS 에서 그대로 통합니다.

> ⚠️ 다만 **앱이 아직 `DATABASE_RO_URL` 을 읽지 않습니다.**
> `config.py` 에 `DATABASE_URL` 만 있습니다(백엔드 수정요청 1번).
> 넣어두어도 무시되므로, 앱 수정이 끝난 뒤 의미가 생깁니다.

---

## 10. 이미지 빌드 (node4)

Jenkins 를 세우기 전이라면 손으로 한 번 올려봅니다.

```bash
vagrant ssh node4

git clone https://github.com/epqlffltm/CloudeDX.git
cd CloudeDX

# 🔴 k3s 는 containerd 라 docker 명령이 없다. podman 을 쓴다.
sudo dnf install -y podman

sudo podman build -f dockerfile.backend -t 192.168.56.15:30500/reluxe-backend:dev .
sudo podman push --tls-verify=false 192.168.56.15:30500/reluxe-backend:dev
```

크롤러도 필요하면 (3.59GB 라 오래 걸립니다):

```bash
sudo podman build -f dockerfile.crawler -t 192.168.56.15:30500/reluxe-crawler:dev .
sudo podman push --tls-verify=false 192.168.56.15:30500/reluxe-crawler:dev
```

**확인**

```bash
curl http://192.168.56.15:30500/v2/_catalog
# {"repositories":["reluxe-backend","reluxe-crawler"]}
```

### 🔴 `--tls-verify=false` 인 이유

로컬 레지스트리를 HTTP 로 띄웠습니다.
`infra/registries.yaml` 의 `insecure_skip_verify: true` 와 짝입니다.
**AWS(ECR)에서는 HTTPS 라 필요 없습니다.**

---

## 11. 앱 배포

```bash
vagrant ssh node0
cd reluxe-gitops

helm upgrade --install reluxe charts/reluxe -n reluxe \
  -f charts/reluxe/values-vagrant.yaml

kubectl get pod -n reluxe -o wide -w
```

### 무슨 일이 일어나나

```
① migrate-job 이 먼저 실행         ← Helm 훅 (pre-install)
   alembic upgrade head 로 DB 스키마 생성
② 완료되면 웹 파드 3개 생성
③ readinessProbe(/ready) 가 DB 확인
④ Ready 가 되면 Service 에 등록
```

### 확인 항목

```bash
# 웹 파드가 node1·2·3 에 하나씩 흩어졌는가 (topologySpread)
kubectl get pod -n reluxe -o wide

# 마이그레이션이 먼저 끝났는가
kubectl get job -n reluxe

# 앱이 응답하는가
curl http://192.168.56.11:30080/health
# {"status":"ok"}

curl http://192.168.56.11:30080/ready
# DB 연결까지 확인
```

**브라우저에서** `http://192.168.56.11:30080` 으로도 열립니다.

---

## 12. 소스 ↔ YAML 이 어떻게 이어지나

```
CloudeDX/dockerfile.backend
        │ podman build
        ▼
192.168.56.15:30500/reluxe-backend:dev        ← 레지스트리
        │
        │ values-vagrant.yaml 이 이 주소를 가리킨다
        │   image:
        │     repository: 192.168.56.15:30500/reluxe-backend
        │     tag: dev
        ▼
charts/reluxe/templates/deployment.yaml
        │   image: {{ include "reluxe.image" . }}
        ▼
파드가 이 이미지를 받아서 뜬다
```

**환경변수는 이렇게 들어갑니다.**

```
values.yaml 의 config 블록
        ▼
templates/configmap.yaml 이 ConfigMap 을 만든다
        ▼
deployment.yaml 의 envFrom 이 통째로 주입
        ▼
app/config.py 의 os.getenv("LOG_LEVEL") 이 읽는다
```

**키 이름이 곧 환경변수 이름**이라 그대로 맞아떨어집니다.

---

## 13. Jenkins · Argo CD (여유 되면)

```bash
helm repo add jenkins https://charts.jenkins.io
helm install jenkins jenkins/jenkins -n infra -f helm-values/jenkins.yaml

helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd -f helm-values/argocd.yaml

kubectl apply -f argocd/application.yaml
```

**Argo CD 초기 비밀번호**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

**접속** — 포트포워딩

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443 --address 0.0.0.0
# 브라우저에서 https://192.168.56.10:8080
```

---

## ⚠️ 자주 막히는 곳

| 증상 | 원인 | 조치 |
|---|---|---|
| **박스 다운로드 404** | Rocky 마이너 버전이 Vault 로 옮겨졌는데 레지스트리가 옛 경로를 가리킴 | Vagrantfile 이 이미 `bento/rockylinux-9` 사용. 그래도 안 되면 파일 안의 대안 참조 |
| **`Timed out while waiting for the machine to boot`** | 첫 부팅이 기본 300초를 넘김 (디스크 리사이즈·RAM 큰 노드) | `boot_timeout = 900` 이미 적용. `vagrant reload <노드>` 또는 한 대씩 `vagrant up` |
| `vagrant up` 이 `mount.vboxsf` 에서 멈춤 | Guest Additions 없음 | Vagrantfile 에서 이미 껐음 |
| VM 이 안 뜨거나 커널 패닉 | Hyper-V 충돌 | 1-1 참조 |
| 전 노드 IP 가 `10.0.2.15` | `--node-ip` 누락 | k3s 재설치 |
| 🔴 **웹훅 타임아웃 · 다른 노드 파드로 curl 실패** | **Flannel 이 NAT 인터페이스를 잡음** | `--flannel-iface=enp0s8`. 확인: `ip -d link show flannel.1 \| grep vxlan` → `local 192.168.56.x` 여야 정상 |
| `tee: /etc/rancher/k3s/registries.yaml: No such file` | 에이전트에는 그 디렉터리가 없음 | `common.sh` 가 미리 생성. 수동이면 `sudo mkdir -p /etc/rancher/k3s` |
| `secret "reluxe-db-app" not found` | `bootstrap.initdb.secret` 을 명시하면 CNPG 가 자동 생성하지 않음 | `kubectl create secret generic reluxe-db-app -n reluxe --type=kubernetes.io/basic-auth --from-literal=username=reluxe --from-literal=password=...` |
| `configmap "reluxe-config" not found` (migrate) | 훅이 일반 리소스보다 먼저 실행됨 | 차트에서 해결됨 (migrate 가 ConfigMap 을 `optional` 로 참조) |
| `sudo k3s: command not found` | RHEL 의 `sudo` 는 `/usr/local/bin` 을 PATH 에서 제외 | `sudo /usr/local/bin/k3s` 또는 kubeconfig 설정 후 `kubectl` |
| 노드 간 파드 통신 안 됨 | firewalld 8472/udp 또는 CIDR | `firewall-cmd --list-all` |
| 파드가 `Pending` | taint 걸린 노드에 toleration 없음 | `kubectl describe pod` |
| `ImagePullBackOff` | `registries.yaml` 미배포 | 7번 다시 |
| 파드가 영원히 `Ready` 안 됨 | DB 없음 (`/ready` 가 DB 확인) | 8번 먼저 |
| `no matches for kind "Cluster"` | CNPG 오퍼레이터 미설치 | 8번 첫 줄 |
| `CreateContainerConfigError` | Secret 없음 | 9번 |
| kubelet 이 자꾸 죽음 | swap 활성 | `free -h` |
| 로그인이 안 됨 | `SESSION_SECRET` 미주입 | 9번 |

---

## 오늘 목표

| 단계 | 내용 | 예상 |
|:--:|---|---|
| 1~2 | 설치 + VM 6대 | 1시간 |
| 3~5 | k3s + taint | 30분 |
| 6~7 | 저장소 clone + 레지스트리 | 30분 |
| 8~9 | DB + Secret | 30분 |
| 10 | 이미지 빌드 | 30분 |
| **11** | **앱 배포** | ← **오늘 여기까지** |
| 13 | Jenkins · Argo CD | 내일 |

**11번까지 가면 차트가 실제로 도는 걸 확인한 겁니다.** 큰 고비는 넘긴 거고요.
