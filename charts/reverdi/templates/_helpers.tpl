{{/*
===========================================================================
공용 템플릿 함수

이름과 라벨을 한 곳에서 만든다. 각 템플릿이 직접 문자열을 쓰면
나중에 이름 규칙을 바꿀 때 전부 고쳐야 하고, 오타가 나면
Service 가 Deployment 를 못 찾는 식으로 조용히 깨진다.

쓰는 법
  name:     {{ include "reverdi.fullname" . }}
  labels:   {{- include "reverdi.labels" . | nindent 4 }}
  selector: {{- include "reverdi.selectorLabels" . | nindent 6 }}

nindent 4 는 "줄바꿈 후 4칸 들여쓰기"다. indent 와 달리 앞에 개행을 넣어준다.
===========================================================================
*/}}

{{/* 차트 이름. values 에서 nameOverride 로 바꿀 수 있다 */}}
{{- define "reverdi.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
전체 이름. 리소스 이름의 기준이 된다.
릴리스 이름이 차트 이름을 이미 포함하면 중복을 피한다.
  helm install reverdi ./charts/reverdi  →  reverdi
  helm install dev    ./charts/reverdi  →  dev-reverdi

63자 제한은 쿠버네티스 라벨 값의 최대 길이다.
*/}}
{{- define "reverdi.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/* 차트 이름-버전. 라벨에 넣어 어느 차트로 만들었는지 추적한다 */}}
{{- define "reverdi.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
전체 라벨. 모든 리소스의 metadata.labels 에 붙인다.
쿠버네티스 권장 라벨(app.kubernetes.io/*)을 따르면
kubectl 이나 모니터링 도구가 자동으로 인식한다.
*/}}
{{- define "reverdi.labels" -}}
helm.sh/chart: {{ include "reverdi.chart" . }}
{{ include "reverdi.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
셀렉터 라벨. Service 가 파드를 찾을 때 쓴다.

🔴 이 두 줄은 배포 후에 바꾸면 안 된다.
   Deployment 의 selector 는 불변 필드라 수정하면 업그레이드가 실패한다.
   그래서 version 처럼 자주 바뀌는 값은 여기 넣지 않는다.
*/}}
{{- define "reverdi.selectorLabels" -}}
app.kubernetes.io/name: {{ include "reverdi.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
컴포넌트별 셀렉터.
웹 파드와 크롤러 파드를 구분해야 Service 가 웹만 잡는다.
  {{- include "reverdi.componentLabels" (dict "ctx" . "component" "web") }}
*/}}
{{- define "reverdi.componentLabels" -}}
{{ include "reverdi.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
이미지 전체 주소. repository 와 tag 를 합친다.
tag 가 비어 있으면 Chart.appVersion 으로 떨어진다 —
로컬에서 값을 안 넣고 helm template 을 돌려볼 때 편하다.
*/}}
{{- define "reverdi.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end }}

{{/* 크롤러 이미지. repository 만 다르고 태그는 공유한다 */}}
{{- define "reverdi.crawlerImage" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- $repo := .Values.crawlerImage.repository | default .Values.image.repository -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end }}

{{/*
ConfigMap / Secret 이름.
템플릿마다 문자열을 직접 쓰면 오타 위험이 있어 함수로 뺀다.
*/}}
{{- define "reverdi.configMapName" -}}
{{- printf "%s-config" (include "reverdi.fullname" .) }}
{{- end }}

{{- define "reverdi.secretName" -}}
{{- .Values.secret.name | default (printf "%s-secret" (include "reverdi.fullname" .)) }}
{{- end }}

{{/*
환경변수 주입 블록.
웹·크롤러·집계·마이그레이션이 전부 같은 설정을 받아야 하므로 한 곳에 둔다.
envFrom 을 쓰면 ConfigMap/Secret 의 키가 그대로 환경변수 이름이 된다.
  LOG_LEVEL 키 → LOG_LEVEL 환경변수
app/config.py 가 os.getenv("LOG_LEVEL") 로 읽으므로 그대로 맞아떨어진다.
*/}}
{{/*
===========================================================================
envFrom — 워크로드별로 받는 Secret 이 다르다

🔴 왜 나누나 (백엔드 보안 점검 4번 · docs/security.md)

  전에는 크롤러·집계·백업도 웹과 같은 Secret 을 통째로 받았다.
  그러면 크롤러 하나가 뚫렸을 때 관리자 비밀번호까지 같이 넘어간다.

  백엔드가 앱 쪽을 먼저 고쳤다.
    · config.py 는 비밀값이 비어도 기록만 하고 통과한다
    · 거부는 그 값을 실제로 쓰는 app/auth.py 임포트 시점에
      require_secrets("ADMIN_PASSWORD","CLIENT_PASSWORD","SESSION_SECRET")
    · 웹만 auth.py 를 임포트하므로 크롤러는 DATABASE_URL 만으로 뜬다

  실제로 확인했다 — 크롤러도 alembic 도 app/auth.py 를 임포트하지 않는다.

  그래서 Secret 을 두 개로 나눠 준다.
    reverdi-secret      웹 전용 — 계정 · SESSION_SECRET · DB
    reverdi-db-secret   배치용 — DB 접속만

⚠️ secretScope.perWorkload 를 켜기 전에
   백엔드 4번 패치가 들어간 이미지여야 한다.
   이전 이미지는 config.py 가 임포트 시점에 관리자 비밀번호를 요구해
   크롤러가 뜨지 않는다.
===========================================================================
*/}}

{{/* 웹 — 전체 Secret */}}
{{- define "reverdi.envFrom" -}}
- configMapRef:
    name: {{ include "reverdi.configMapName" . }}
- secretRef:
    name: {{ include "reverdi.secretName" . }}
{{- end }}

{{/*
배치(크롤러·집계·백업) — DB 접속만.
perWorkload 가 꺼져 있으면 웹과 같은 Secret 을 쓴다(기존 동작).
*/}}
{{- define "reverdi.envFromBatch" -}}
- configMapRef:
    name: {{ include "reverdi.configMapName" . }}
- secretRef:
{{- if .Values.secretScope.perWorkload }}
    name: {{ .Values.secretScope.dbSecretName }}
{{- else }}
    name: {{ include "reverdi.secretName" . }}
{{- end }}
{{- end }}
