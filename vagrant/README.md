# Vagrant ?대윭?ㅽ꽣 ??泥섏쓬遺???앷퉴吏

> Rocky Linux 9 쨌 k3s 쨌 VM 6?
> **?꾨Т寃껊룄 ??源붾┛ ?곹깭**?먯꽌 ?깆씠 ???뚭퉴吏????怨쇱젙?낅땲??

---

## 0. ?꾩껜 洹몃┝ ??臾댁뾿???대뵒濡?媛??
```
[??PC (Windows)]
  Vagrant + VirtualBox
     ?붴? VM 6?瑜?留뚮뱺??     ?붴? helm.exe ??李⑦듃 臾몃쾿 寃?ъ슜 (?대윭?ㅽ꽣 ?묒냽? VM ?덉뿉??

[??μ냼 2媛?
  CloudeDX          ???뚯뒪 쨌 Dockerfile     ??node4 ?먯꽌 clone (?대?吏 鍮뚮뱶??
  reverdi-gitops     李⑦듃 쨌 infra 쨌 argocd    ??node0 ?먯꽌 clone (諛고룷??

[VM 6?]
  node0   而⑦듃濡??뚮젅??         ??kubectl 쨌 helm 紐낅졊???ш린??移쒕떎
  node1~3 ???뚮뱶 + DB ?뚮뱶
  node4   ?щ·??쨌 ?대?吏 鍮뚮뱶    ???뚯뒪瑜?諛쏆븘 ?대?吏瑜?留뚮뱺??  node5   ?덉??ㅽ듃由?쨌 MinIO 쨌 Jenkins 쨌 Argo CD
```

### ?뵶 ??μ냼媛 ???섏씤媛

| ??μ냼 | ?대뒗 寃?| ?꾧? 而ㅻ컠 |
|---|---|---|
| **CloudeDX** | `app/` 쨌 `dockerfile.*` 쨌 `Jenkinsfile` | 媛쒕컻??|
| **reverdi-gitops** | `charts/` 쨌 `infra/` 쨌 `argocd/` 쨌 `helm-values/` | Jenkins (?대?吏 ?쒓렇留? |

媛숈? ??μ냼???먮㈃ **臾댄븳 猷⑦봽**媛 ?⑸땲??
Jenkins 媛 鍮뚮뱶 ???쒓렇 而ㅻ컠 ??洹?而ㅻ컠??Jenkins 瑜??ㅼ떆 源⑥? ??諛섎났.

---

## 1. ??PC 以鍮?(Windows)

### 1-1. VirtualBox

`https://www.virtualbox.org/wiki/Downloads` ??Windows hosts

> ?좑툘 **Hyper-V ? 異⑸룎?????덉뒿?덈떎.** WSL2 ??Docker Desktop ???곌퀬 ?덈떎硫?> VirtualBox 7.1 ?댁긽???곗꽭?? 洹몃옒??VM ?????⑤㈃ 愿由ъ옄 PowerShell ?먯꽌:
> ```powershell
> bcdedit /enum | findstr hypervisorlaunchtype
> ```
> `Off` 濡?諛붽씀硫?VirtualBox ???섏?留?**WSL2쨌Docker Desktop ???④퍡 二쎌뒿?덈떎.**

### 1-2. Vagrant

`https://developer.hashicorp.com/vagrant/downloads` ??Windows AMD64

?ㅼ튂 ??**PowerShell ???덈줈 ?댁뼱??* PATH 媛 諛섏쁺?⑸땲??

```powershell
vagrant --version
VBoxManage --version
```

### 1-3. ?붿뒪???뚮윭洹몄씤

```powershell
vagrant plugin install vagrant-disksize
```

**node4(60GB)쨌node5(100GB)??湲곕낯 諛뺤뒪 ?⑸웾?쇰줈 遺議깊빀?덈떎.**

### 1-4. (?좏깮) helm.exe

李⑦듃 臾몃쾿????PC ?먯꽌 寃?ы븷 ?뚮쭔 ?꾩슂?⑸땲??
`https://get.helm.sh/helm-v3.16.3-windows-amd64.zip` ??`helm.exe` ?섎굹留?爰쇰궡 ?곷땲??

> ?대윭?ㅽ꽣 ?묒냽? VM ?덉뿉???섎?濡??놁뼱??吏꾪뻾?⑸땲??

---

## 2. VM 6? 留뚮뱾湲?
```powershell
cd D:\project\reverdi\vagrant
vagrant up
```

**30~60遺?* 嫄몃┰?덈떎. 諛뺤뒪 ?ㅼ슫濡쒕뱶 + `dnf install` ?ы븿?낅땲??

??????뺤씤?섎ŉ ?щ━?ㅻ㈃:

```powershell
vagrant up node0
vagrant status
```

### ?좑툘 諛뺤뒪 ?ㅼ슫濡쒕뱶媛 404 濡??ㅽ뙣?섎㈃

```
An error occurred while downloading the remote file.
The requested URL returned error: 404
```

**Rocky 怨듭떇 諛뺤뒪(`rockylinux/9`)?먯꽌 諛섎났?섎뒗 臾몄젣**?낅땲??
留덉씠??踰꾩쟾??Vault 濡???꺼吏???Vagrant ?덉??ㅽ듃由?寃쎈줈媛 媛깆떊?섏? ?딆븘 ?앷퉩?덈떎.

Vagrantfile ? ?대? **`bento/rockylinux-9`**(Chef 愿由? 留곹겕 ?덉젙??瑜??곌퀬 ?덉뒿?덈떎.
洹몃옒?????섎㈃ Vagrantfile ?덉쓽 二쇱꽍???????媛吏媛 ?덉뒿?덈떎.

```powershell
# 罹먯떆媛 瑗ъ??쇰㈃ 吏?곌퀬 ?ㅼ떆
vagrant box list
vagrant box remove rockylinux/9 --all
vagrant up
```

### ?좑툘 `Timed out while waiting for the machine to boot`

泥?遺?낆씠 湲곕낯 300珥??덉뿉 ???앸궃 寃곷땲?? **?뚯씪???섎せ??寃??꾨떃?덈떎.**

?뱁엳 **node5** ??RAM 16GB + ?붿뒪??100GB 由ъ궗?댁쫰媛 寃뱀퀜 ?ㅻ옒 嫄몃┰?덈떎.
Vagrantfile ??`boot_timeout = 900` ???ｌ뼱?吏留? 洹몃옒??嫄몃━硫????섎━?몄슂.

**癒쇱? ?ㅼ젣濡?遺??以묒씤吏 ?뺤씤**

VirtualBox 愿由ъ옄?먯꽌 ?대떦 VM 李쎌쓣 ?댁뼱蹂댁꽭??
濡쒓렇???꾨＼?꾪듃媛 ???덉쑝硫?**遺?낆? ?먭퀬 Vagrant 留?湲곕떎由щ떎 ?ш린??* 寃껋엯?덈떎.

```powershell
vagrant status              # ?대뒓 VM ??running ?몄?
vagrant reload node5        # 洹?VM 留??ㅼ떆
vagrant provision node5     # ?꾨줈鍮꾩??앸쭔 ?ㅼ떆 (遺?낆? ?먯쓣 ??
```

**?몄뒪?멸? 踰꾧굅?곕㈃ ?????*

6?瑜???踰덉뿉 ?щ━硫??붿뒪??I/O 媛 紐곕┰?덈떎.

```powershell
vagrant up node0
vagrant up node1
vagrant up node2
vagrant up node3
vagrant up node4
vagrant up node5
```

?먮젮?????몄씠 ?뺤떎?⑸땲?? ?뱁엳 **node4쨌node5 ???붿뒪?ш? 而ㅼ꽌** ?곕줈 ?щ━??寃??レ뒿?덈떎.

### ?뺤긽 ?좏샇

媛?VM ?꾨줈鍮꾩???留덉?留됱뿉 ?대젃寃??섏샃?덈떎.

```
SELinux : Enforcing      ???닿쾶 留욎뒿?덈떎. ?꾩? ?딆뒿?덈떎
Swap    : 0B             ??0 ?댁뼱??kubelet ????二쎌뒿?덈떎
以鍮??꾨즺: node0
```

### VM 愿由?
```powershell
vagrant status              # 6? ?곹깭
vagrant halt                # ?꾩껜 ?뺤? (?묒뾽 ?앸궇 ??
vagrant up                  # ?ㅼ떆 ?쒖옉
vagrant reload node1        # ???留??щ???vagrant destroy -f          # ?꾨? ??젣 (泥섏쓬遺???ㅼ떆)
```

> ?뮕 **?묒뾽???앸굹硫?`vagrant halt`.** 6?媛 RAM 40GB 瑜??↔퀬 ?덉뒿?덈떎.

---

## 3. SSH ?묒냽

### 3-1. 湲곕낯

```powershell
vagrant ssh node0
```

鍮꾨?踰덊샇媛 ?꾩슂 ?놁뒿?덈떎. Vagrant 媛 ?ㅻ? ?먮룞 愿由ы빀?덈떎. ?섏삱 ?뚮뒗 `exit`.

### 3-2. VM ?쇰━

```bash
# node0 ?덉뿉??ssh vagrant@192.168.56.11      # 鍮꾨?踰덊샇: vagrant
```

### 3-3. ?뵶 ?뚯씪??VM ?쇰줈 ??린??踰?
**怨듭쑀 ?대뜑瑜?猿먯뒿?덈떎.** Rocky 怨듭떇 諛뺤뒪??Guest Additions 媛 ?놁뼱??
耳쒕몢硫?`vagrant up` ??`mount.vboxsf: No such device` 濡?硫덉땅?덈떎.

**??git clone (沅뚯옣)**

```bash
vagrant ssh node4
git clone https://github.com/epqlffltm/CloudeDX.git
```

媛??源붾걫?⑸땲?? VM ? NAT 濡??명꽣?룹뿉 ?섍컩?덈떎.

**???쒖??낅젰?쇰줈 諛?대꽔湲?*

```powershell
Get-Content scripts\k3s-server.sh | vagrant ssh node0 -c "cat > /tmp/k3s-server.sh"
vagrant ssh node0 -c "sudo bash /tmp/k3s-server.sh"
```

**??遺숈뿬?ｊ린**

```bash
vagrant ssh node0
cat > /tmp/setup.sh <<'EOF'
(?댁슜 遺숈뿬?ｊ린)
EOF
sudo bash /tmp/setup.sh
```

> ?좑툘 ?쒓? 二쇱꽍?????ㅽ겕由쏀듃???곕????몄퐫???뚮Ц??源⑥쭏 ???덉뒿?덈떎. 洹몃윺 ???좊쾲???곗꽭??

---

## 4. k3s ?ㅼ튂

### 4-1. node0 ???쒕쾭

```powershell
Get-Content scripts\k3s-server.sh | vagrant ssh node0 -c "cat > /tmp/k3s-server.sh"
vagrant ssh node0 -c "sudo bash /tmp/k3s-server.sh"
```

留덉?留됱뿉 **?좏겙**???섏샃?덈떎. 蹂듭궗?대몢?몄슂.

```
K10abc123def456...::server:xxxxxxxx
```

### 4-2. node1~5 ???먯씠?꾪듃

**IP ? ?쇰꺼??媛곴컖 ?ㅻ쫭?덈떎.**

```powershell
$T = "?ш린???좏겙_遺숈뿬?ｊ린"

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

### 4-3. ?뺤씤

```bash
vagrant ssh node0
kubectl get nodes -o wide
```

**6?媛 `Ready`** ?닿퀬 **INTERNAL-IP 媛 媛곸옄 ?ㅻⅨ吏** 遊낅땲??

```
NAME    STATUS   INTERNAL-IP
node0   Ready    192.168.56.10
node1   Ready    192.168.56.11
...
```

> ?뵶 ?꾨? `10.0.2.15` 濡?媛숈쑝硫?`--node-ip` 媛 ??癒뱀? 寃곷땲??
> Vagrant ??NAT ?명꽣?섏씠?ㅻ? ?≪? 嫄곕씪 ?몃뱶 媛??듭떊??源⑥쭛?덈떎. ?ъ꽕移섑븯?몄슂.

---

## 5. taint 쨌 ?ㅼ엫?ㅽ럹?댁뒪

**node0 ?먯꽌** ?ㅽ뻾?⑸땲??

```powershell
Get-Content scripts\setup-cluster.sh | vagrant ssh node0 -c "cat > /tmp/s.sh"
vagrant ssh node0 -c "sudo bash /tmp/s.sh"
```

?쇰꺼 蹂댁젙 ??taint ???ㅼ엫?ㅽ럹?댁뒪 4媛?`reverdi`쨌`infra`쨌`argocd`쨌`monitoring`)瑜?留뚮벊?덈떎.

> ?뵶 **taint 瑜?鍮쇰㉨?쇰㈃ ???⑸땲??** label 留뚯쑝濡쒕뒗 ?ㅻⅨ ?뚮뱶媛
> 諛곗튂쨌?명봽???몃뱶濡??덉뼱 ?ㅼ뼱?ㅻ뒗 嫄?留됱? 紐삵빀?덈떎.

---

## 6. 諛고룷????μ냼 clone (node0)

```bash
vagrant ssh node0
git clone https://github.com/jpnjb0918-glitch/reverdi-gitops.git
cd reverdi-gitops
ls
# argocd  charts  helm-values  infra
```

**?욎쑝濡쒖쓽 kubectl 쨌 helm 紐낅졊? ?꾨? ???붾젆?곕━?먯꽌** 移⑸땲??

> ?뮕 ??PC ?먯꽌 ?뚯씪??怨좎낀?쇰㈃ `git pull` 濡?諛쏆븘?ㅼ꽭??
> VM ?덉뿉??吏곸젒 怨좎튂硫??ㅼ떆 而ㅻ컠?섍린 踰덇굅濡?뒿?덈떎.

---

## 7. ?덉??ㅽ듃由?
```bash
kubectl apply -f infra/registry.yaml
kubectl get pod -n infra -w      # Running ???뚭퉴吏
```

?뚮뱶媛 ?⑤㈃ **???몃뱶???묒냽 ?ㅼ젙??諛고룷**?⑸땲??

```powershell
# PowerShell ??vagrant ?붾젆?곕━?먯꽌
foreach ($n in "node0","node1","node2","node3","node4","node5") {
  Get-Content ..\infra\registries.yaml | vagrant ssh $n -c "sudo tee /etc/rancher/k3s/registries.yaml > /dev/null"
  if ($n -eq "node0") { vagrant ssh $n -c "sudo systemctl restart k3s" }
  else                { vagrant ssh $n -c "sudo systemctl restart k3s-agent" }
  Write-Host "$n ?꾨즺"
}
```

> ?뵶 `registries.yaml` ? **kubectl ??곸씠 ?꾨떃?덈떎.**
> 荑좊쾭?ㅽ떚??由ъ냼?ㅺ? ?꾨땲??k3s(containerd)???몃뱶 ?ㅼ젙 ?뚯씪?낅땲??
> ????쇰룄 鍮좎?硫?**洹??몃뱶?먯꽌留?* `ImagePullBackOff` 媛 ?⑸땲??

**?뺤씤**

```bash
curl http://192.168.56.15:30500/v2/_catalog
# {"repositories":[]}
```

---

## 8. DB (CloudNativePG)

**?ㅽ띁?덉씠?곕? 癒쇱?** 源붿븘???⑸땲?? ?놁쑝硫?`Cluster` 由ъ냼?ㅻ? 紐??뚯븘?ｌ뒿?덈떎.

```bash
# node0 ??helm ?ㅼ튂
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace

# ?ㅽ띁?덉씠?곌? Running ?????ㅼ뿉
kubectl apply -f infra/postgres-cluster.yaml
kubectl get cluster -n reverdi -w
```

`instances: 3` ???꾨? ?⑤㈃ ?⑸땲?? **primary 1 + replica 2** ?낅땲??

```bash
kubectl get pod -n reverdi -o wide     # node1~3 ???⑹뼱議뚮뒗吏
```

---

## 9. ?뵶 ??Secret 留뚮뱾湲?
**李⑦듃??Secret ??留뚮뱾吏 ?딆뒿?덈떎. 李몄“留??⑸땲??**

```bash
# CloudNativePG 媛 留뚮뱺 DB 鍮꾨?踰덊샇瑜?爰쇰궦??PW=$(kubectl get secret reverdi-db-app -n reverdi -o jsonpath='{.data.password}' | base64 -d)
echo "DB 鍮꾨?踰덊샇: $PW"

kubectl create secret generic reverdi-secret -n reverdi \
  --from-literal=DATABASE_URL="postgresql+asyncpg://reverdi:${PW}@reverdi-db-rw.reverdi.svc:5432/reverdi" \
  --from-literal=DATABASE_RO_URL="postgresql+asyncpg://reverdi:${PW}@reverdi-db-ro.reverdi.svc:5432/reverdi" \
  --from-literal=SESSION_SECRET="$(python3 -c 'import secrets;print(secrets.token_hex(32))')" \
  --from-literal=ADMIN_USERNAME=admin \
  --from-literal=ADMIN_PASSWORD="$(openssl rand -hex 12)" \
  --from-literal=CLIENT_USERNAME=client \
  --from-literal=CLIENT_PASSWORD="$(openssl rand -hex 12)"
```

### ???닿쾶 以묒슂?쒓?

**`SESSION_SECRET` ???놁쑝硫?濡쒓렇?몄씠 ?숈옉?섏? ?딆뒿?덈떎.**

`app/config.py` ??誘몄꽕????`secrets.token_hex(32)` 濡?**?뚮뱶留덈떎 ?ㅻⅨ ?쒕뜡 媛?*??留뚮벊?덈떎.
replicas 3 ?대㈃ ???뚮뱶媛 ?쒕줈??荑좏궎瑜??몄젙?섏? ?딆뒿?덈떎.

**`-rw` / `-ro` 濡??섎돏 ?댁쑀**

CloudNativePG 媛 ???쒕퉬?ㅻ? ?먮룞?쇰줈 留뚮벊?덈떎.
?곌린??primary(`-rw`), ?쎄린??replica(`-ro`) 濡?媛묐땲??
**RDS ??writer/reader ?붾뱶?ъ씤?몄? 媛숈? 紐⑥뼇**?대씪, ?ш린??寃利앺븳 寃?AWS ?먯꽌 洹몃?濡??듯빀?덈떎.

> ?좑툘 ?ㅻ쭔 **?깆씠 ?꾩쭅 `DATABASE_RO_URL` ???쎌? ?딆뒿?덈떎.**
> `config.py` ??`DATABASE_URL` 留??덉뒿?덈떎(諛깆뿏???섏젙?붿껌 1踰?.
> ?ｌ뼱?먯뼱??臾댁떆?섎?濡? ???섏젙???앸궃 ???섎?媛 ?앷퉩?덈떎.

---

## 10. ?대?吏 鍮뚮뱶 (node4)

Jenkins 瑜??몄슦湲??꾩씠?쇰㈃ ?먯쑝濡???踰??щ젮遊낅땲??

```bash
vagrant ssh node4

git clone https://github.com/epqlffltm/CloudeDX.git
cd CloudeDX

# ?뵶 k3s ??containerd ??docker 紐낅졊???녿떎. podman ???대떎.
sudo dnf install -y podman

sudo podman build -f dockerfile.backend -t 192.168.56.15:30500/reverdi-backend:dev .
sudo podman push --tls-verify=false 192.168.56.15:30500/reverdi-backend:dev
```

?щ·?щ룄 ?꾩슂?섎㈃ (3.59GB ???ㅻ옒 嫄몃┰?덈떎):

```bash
sudo podman build -f dockerfile.crawler -t 192.168.56.15:30500/reverdi-crawler:dev .
sudo podman push --tls-verify=false 192.168.56.15:30500/reverdi-crawler:dev
```

**?뺤씤**

```bash
curl http://192.168.56.15:30500/v2/_catalog
# {"repositories":["reverdi-backend","reverdi-crawler"]}
```

### ?뵶 `--tls-verify=false` ???댁쑀

濡쒖뺄 ?덉??ㅽ듃由щ? HTTP 濡??꾩썱?듬땲??
`infra/registries.yaml` ??`insecure_skip_verify: true` ? 吏앹엯?덈떎.
**AWS(ECR)?먯꽌??HTTPS ???꾩슂 ?놁뒿?덈떎.**

---

## 11. ??諛고룷

```bash
vagrant ssh node0
cd reverdi-gitops

helm upgrade --install reverdi charts/reverdi -n reverdi \
  -f charts/reverdi/values-vagrant.yaml

kubectl get pod -n reverdi -o wide -w
```

### 臾댁뒯 ?쇱씠 ?쇱뼱?섎굹

```
??migrate-job ??癒쇱? ?ㅽ뻾         ??Helm ??(pre-install)
   alembic upgrade head 濡?DB ?ㅽ궎留??앹꽦
???꾨즺?섎㈃ ???뚮뱶 3媛??앹꽦
??readinessProbe(/ready) 媛 DB ?뺤씤
??Ready 媛 ?섎㈃ Service ???깅줉
```

### ?뺤씤 ??ぉ

```bash
# ???뚮뱶媛 node1쨌2쨌3 ???섎굹???⑹뼱議뚮뒗媛 (topologySpread)
kubectl get pod -n reverdi -o wide

# 留덉씠洹몃젅?댁뀡??癒쇱? ?앸궗?붽?
kubectl get job -n reverdi

# ?깆씠 ?묐떟?섎뒗媛
curl http://192.168.56.11:30080/health
# {"status":"ok"}

curl http://192.168.56.11:30080/ready
# DB ?곌껐源뚯? ?뺤씤
```

**釉뚮씪?곗??먯꽌** `http://192.168.56.11:30080` ?쇰줈???대┰?덈떎.

---

## 12. ?뚯뒪 ??YAML ???대뼸寃??댁뼱吏??
```
CloudeDX/dockerfile.backend
        ??podman build
        ??192.168.56.15:30500/reverdi-backend:dev        ???덉??ㅽ듃由?        ??        ??values-vagrant.yaml ????二쇱냼瑜?媛由ы궓??        ??  image:
        ??    repository: 192.168.56.15:30500/reverdi-backend
        ??    tag: dev
        ??charts/reverdi/templates/deployment.yaml
        ??  image: {{ include "reverdi.image" . }}
        ???뚮뱶媛 ???대?吏瑜?諛쏆븘???щ떎
```

**?섍꼍蹂?섎뒗 ?대젃寃??ㅼ뼱媛묐땲??**

```
values.yaml ??config 釉붾줉
        ??templates/configmap.yaml ??ConfigMap ??留뚮뱺??        ??deployment.yaml ??envFrom ???듭㎏濡?二쇱엯
        ??app/config.py ??os.getenv("LOG_LEVEL") ???쎈뒗??```

**???대쫫??怨??섍꼍蹂???대쫫**?대씪 洹몃?濡?留욎븘?⑥뼱吏묐땲??

---

## 13. Jenkins 쨌 Argo CD (?ъ쑀 ?섎㈃)

```bash
helm repo add jenkins https://charts.jenkins.io
helm install jenkins jenkins/jenkins -n infra -f helm-values/jenkins.yaml

helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd -f helm-values/argocd.yaml

kubectl apply -f argocd/application.yaml
```

**Argo CD 珥덇린 鍮꾨?踰덊샇**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

**?묒냽** ???ы듃?ъ썙??
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443 --address 0.0.0.0
# 釉뚮씪?곗??먯꽌 https://192.168.56.10:8080
```

---

## ?좑툘 ?먯＜ 留됲엳??怨?
| 利앹긽 | ?먯씤 | 議곗튂 |
|---|---|---|
| **諛뺤뒪 ?ㅼ슫濡쒕뱶 404** | Rocky 留덉씠??踰꾩쟾??Vault 濡???꺼議뚮뒗???덉??ㅽ듃由ш? ??寃쎈줈瑜?媛由ы궡 | Vagrantfile ???대? `bento/rockylinux-9` ?ъ슜. 洹몃옒?????섎㈃ ?뚯씪 ?덉쓽 ???李몄“ |
| **`Timed out while waiting for the machine to boot`** | 泥?遺?낆씠 湲곕낯 300珥덈? ?섍? (?붿뒪??由ъ궗?댁쫰쨌RAM ???몃뱶) | `boot_timeout = 900` ?대? ?곸슜. `vagrant reload <?몃뱶>` ?먮뒗 ?????`vagrant up` |
| `vagrant up` ??`mount.vboxsf` ?먯꽌 硫덉땄 | Guest Additions ?놁쓬 | Vagrantfile ?먯꽌 ?대? 猿먯쓬 |
| VM ?????④굅??而ㅻ꼸 ?⑤땳 | Hyper-V 異⑸룎 | 1-1 李몄“ |
| ???몃뱶 IP 媛 `10.0.2.15` | `--node-ip` ?꾨씫 | k3s ?ъ꽕移?|
| ?뵶 **?뱁썒 ??꾩븘??쨌 ?ㅻⅨ ?몃뱶 ?뚮뱶濡?curl ?ㅽ뙣** | **Flannel ??NAT ?명꽣?섏씠?ㅻ? ?≪쓬** | `--flannel-iface=enp0s8`. ?뺤씤: `ip -d link show flannel.1 \| grep vxlan` ??`local 192.168.56.x` ?ъ빞 ?뺤긽 |
| `tee: /etc/rancher/k3s/registries.yaml: No such file` | ?먯씠?꾪듃?먮뒗 洹??붾젆?곕━媛 ?놁쓬 | `common.sh` 媛 誘몃━ ?앹꽦. ?섎룞?대㈃ `sudo mkdir -p /etc/rancher/k3s` |
| `secret "reverdi-db-app" not found` | `bootstrap.initdb.secret` ??紐낆떆?섎㈃ CNPG 媛 ?먮룞 ?앹꽦?섏? ?딆쓬 | `kubectl create secret generic reverdi-db-app -n reverdi --type=kubernetes.io/basic-auth --from-literal=username=reverdi --from-literal=password=...` |
| `configmap "reverdi-config" not found` (migrate) | ?낆씠 ?쇰컲 由ъ냼?ㅻ낫??癒쇱? ?ㅽ뻾??| 李⑦듃?먯꽌 ?닿껐??(migrate 媛 ConfigMap ??`optional` 濡?李몄“) |
| `sudo k3s: command not found` | RHEL ??`sudo` ??`/usr/local/bin` ??PATH ?먯꽌 ?쒖쇅 | `sudo /usr/local/bin/k3s` ?먮뒗 kubeconfig ?ㅼ젙 ??`kubectl` |
| ?몃뱶 媛??뚮뱶 ?듭떊 ????| firewalld 8472/udp ?먮뒗 CIDR | `firewall-cmd --list-all` |
| ?뚮뱶媛 `Pending` | taint 嫄몃┛ ?몃뱶??toleration ?놁쓬 | `kubectl describe pod` |
| `ImagePullBackOff` | `registries.yaml` 誘몃같??| 7踰??ㅼ떆 |
| ?뚮뱶媛 ?곸썝??`Ready` ????| DB ?놁쓬 (`/ready` 媛 DB ?뺤씤) | 8踰?癒쇱? |
| `no matches for kind "Cluster"` | CNPG ?ㅽ띁?덉씠??誘몄꽕移?| 8踰?泥?以?|
| `CreateContainerConfigError` | Secret ?놁쓬 | 9踰?|
| kubelet ???먭씀 二쎌쓬 | swap ?쒖꽦 | `free -h` |
| 濡쒓렇?몄씠 ????| `SESSION_SECRET` 誘몄＜??| 9踰?|

---

## ?ㅻ뒛 紐⑺몴

| ?④퀎 | ?댁슜 | ?덉긽 |
|:--:|---|---|
| 1~2 | ?ㅼ튂 + VM 6? | 1?쒓컙 |
| 3~5 | k3s + taint | 30遺?|
| 6~7 | ??μ냼 clone + ?덉??ㅽ듃由?| 30遺?|
| 8~9 | DB + Secret | 30遺?|
| 10 | ?대?吏 鍮뚮뱶 | 30遺?|
| **11** | **??諛고룷** | ??**?ㅻ뒛 ?ш린源뚯?** |
| 13 | Jenkins 쨌 Argo CD | ?댁씪 |

**11踰덇퉴吏 媛硫?李⑦듃媛 ?ㅼ젣濡??꾨뒗 嫄??뺤씤??寃곷땲??** ??怨좊퉬???섍릿 嫄곌퀬??

