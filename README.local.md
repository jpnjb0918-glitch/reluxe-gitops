# reluxe Helm 차트 — A 담당분 (1~8번)

`④_작성할_YAML목록.md`의 그룹 A 8개 파일입니다.

## 파일

| # | 파일 | 무엇을 하나 |
|---|---|---|
| 1 | `Chart.yaml` | 차트 이름·버전 (메타데이터) |
| 2 | `values.yaml` | 🔴 **모든 템플릿이 참조하는 값의 원본** |
| 3 | `templates/_helpers.tpl` | 이름·라벨 생성 함수 |
| 4 | `templates/configmap.yaml` | 설정값 통 (비밀 아닌 것) |
| 5 | `templates/secret.yaml` | 비밀값 통 — 기본 `create: false` |
| 6 | `templates/deployment.yaml` | 🔴 FastAPI 파드 3개 |
| 7 | `templates/service.yaml` | 파드를 하나의 이름으로 |
| 8 | `templates/ingress.yaml` | 외부 진입 (AWS 전용, 조건부) |

## 처음 할 일

```bash
# 1) 문법 검사
helm lint charts/reluxe

# 2) 렌더링 결과를 눈으로 확인 — 클러스터에 올리기 전 필수
helm template charts/reluxe --debug | less

# 3) Secret 을 먼저 만든다 (차트는 참조만 한다)
kubectl create namespace reluxe
kubectl create secret generic reluxe-secret -n reluxe \
  --from-literal=DATABASE_URL='postgresql+asyncpg://reluxe:PW@reluxe-db-rw.reluxe.svc:5432/reluxe' \
  --from-literal=DATABASE_RO_URL='postgresql+asyncpg://reluxe:PW@reluxe-db-ro.reluxe.svc:5432/reluxe' \
  --from-literal=SESSION_SECRET="$(python3 -c 'import secrets;print(secrets.token_hex(32))')" \
  --from-literal=ADMIN_USERNAME=admin --from-literal=ADMIN_PASSWORD='바꿀것' \
  --from-literal=CLIENT_USERNAME=client --from-literal=CLIENT_PASSWORD='바꿀것'

# 4) 설치
helm upgrade --install reluxe charts/reluxe -n reluxe \
  --set image.repository=192.168.56.15:30500/reluxe-backend \
  --set image.tag=dev
```

## 🔴 B·C 에게 넘길 것

**B (배치 워크로드)** — `values.yaml` 의 아래 키를 참조하세요.

```
crawler.schedule / crawler.shmSize / crawler.nodeSelector / crawler.tolerations
crawler.resources / aggregate.* / pgdump.* / migrate.*
pdb.* / hpa.*
```

`deployment.yaml` 을 복사해 고치면 됩니다. 공통 함수는 `_helpers.tpl` 에 있습니다.

```
{{ include "reluxe.fullname" . }}       이름
{{ include "reluxe.labels" . }}         전체 라벨
{{ include "reluxe.envFrom" . }}        ConfigMap + Secret 주입
{{ include "reluxe.crawlerImage" . }}   크롤러 이미지 주소
```

**C (인프라)** — 아래 두 값을 알려주세요. `values-*.yaml` 에 들어갑니다.

```
image.repository   레지스트리 주소 (예: 192.168.56.15:30500/reluxe-backend)
secret 의 DB 주소  CloudNativePG 가 만드는 -rw / -ro 서비스 이름
```

## ⚠️ 알아둘 것

**`DATABASE_RO_URL` 은 앱이 아직 읽지 않습니다.**
`app/config.py` 에 `DATABASE_URL` 만 있습니다. 백엔드 수정(요청 1번)이 끝나야 의미가 생깁니다.
지금 Secret 에 넣어두어도 무시되므로, 넣어두고 기다리면 됩니다.

**`SESSION_SECRET` 은 반드시 주입해야 합니다.**
미설정이면 `config.py` 가 파드마다 랜덤 값을 만듭니다(`secrets.token_hex(32)`).
replicas 3 이면 세 파드가 서로의 쿠키를 인정하지 않아 **로그인이 동작하지 않습니다.**

**`ENABLE_CRAWLER` 는 `"false"` 로 고정했습니다.**
코드 기본값이 `True` 라 명시하지 않으면 웹 파드에서도 크롤링이 돕니다.
크롤링은 배치 노드의 CronJob 이 담당합니다.

## 검증 내역

저장소 코드와 대조 확인한 항목입니다.

| 주장 | 근거 |
|---|---|
| 컨테이너 포트 8000 | `dockerfile.backend` 의 `EXPOSE 8000` |
| 비루트 uid 10001 | `useradd --create-home --uid 10001 appuser` |
| `/health` 가 DB 미확인 | `app/routers/health.py` — "의존 서비스는 일부러 확인하지 않는다" |
| `/health`·`/ready` 에 prefix 없음 | `app.include_router(health_router)` — prefix 인자 없음 |
| `"false"` 가 False 로 해석 | `_bool_env`: `raw in ("1","true","yes","on")` |
| `API_PREFIX` 는 환경변수 아님 | `API_PREFIX = "/api"` 코드 상수 |
| `ALLOWED_ORIGINS` 는 비워야 함 | 주석 — "비워두면 CORS 미들웨어를 아예 붙이지 않는다" |
| 환경변수 이름 18개 | `app/config.py` 대문자 상수 전수 대조 |

**⚠️ 확인하지 못한 것**

`helm lint` · `helm template` 을 실제로 돌리지 못했습니다(작업 환경의 네트워크 제한).
위 검증은 문법과 논리를 다른 방식으로 재현한 것이라, **Go 템플릿 엔진의 실제 동작**
(`nindent` 들여쓰기, `{{-` 공백 제어)은 팀에서 확인해야 합니다.

특히 `helm template --debug` 출력의 **들여쓰기를 눈으로** 봐주세요.
