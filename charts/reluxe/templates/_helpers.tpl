{{/*
===========================================================================
공용 템플릿 함수

이름과 라벨을 한 곳에서 만든다. 각 템플릿이 직접 문자열을 쓰면
나중에 이름 규칙을 바꿀 때 전부 고쳐야 하고, 오타가 나면
Service 가 Deployment 를 못 찾는 식으로 조용히 깨진다.

쓰는 법
  name:     {{ include "reluxe.fullname" . }}
  labels:   {{- include "reluxe.labels" . | nindent 4 }}
  selector: {{- include "reluxe.selectorLabels" . | nindent 6 }}

nindent 4 는 "줄바꿈 후 4칸 들여쓰기"다. indent 와 달리 앞에 개행을 넣어준다.
===========================================================================
*/}}

{{/* 차트 이름. values 에서 nameOverride 로 바꿀 수 있다 */}}
{{- define "reluxe.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
전체 이름. 리소스 이름의 기준이 된다.
릴리스 이름이 차트 이름을 이미 포함하면 중복을 피한다.
  helm install reluxe ./charts/reluxe  →  reluxe
  helm install dev    ./charts/reluxe  →  dev-reluxe

63자 제한은 쿠버네티스 라벨 값의 최대 길이다.
*/}}
{{- define "reluxe.fullname" -}}
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
{{- define "reluxe.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
전체 라벨. 모든 리소스의 metadata.labels 에 붙인다.
쿠버네티스 권장 라벨(app.kubernetes.io/*)을 따르면
kubectl 이나 모니터링 도구가 자동으로 인식한다.
*/}}
{{- define "reluxe.labels" -}}
helm.sh/chart: {{ include "reluxe.chart" . }}
{{ include "reluxe.selectorLabels" . }}
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
{{- define "reluxe.selectorLabels" -}}
app.kubernetes.io/name: {{ include "reluxe.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
컴포넌트별 셀렉터.
웹 파드와 크롤러 파드를 구분해야 Service 가 웹만 잡는다.
  {{- include "reluxe.componentLabels" (dict "ctx" . "component" "web") }}
*/}}
{{- define "reluxe.componentLabels" -}}
{{ include "reluxe.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
이미지 전체 주소. repository 와 tag 를 합친다.
tag 가 비어 있으면 Chart.appVersion 으로 떨어진다 —
로컬에서 값을 안 넣고 helm template 을 돌려볼 때 편하다.
*/}}
{{- define "reluxe.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end }}

{{/* 크롤러 이미지. repository 만 다르고 태그는 공유한다 */}}
{{- define "reluxe.crawlerImage" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- $repo := .Values.crawlerImage.repository | default .Values.image.repository -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end }}

{{/*
ConfigMap / Secret 이름.
템플릿마다 문자열을 직접 쓰면 오타 위험이 있어 함수로 뺀다.
*/}}
{{- define "reluxe.configMapName" -}}
{{- printf "%s-config" (include "reluxe.fullname" .) }}
{{- end }}

{{- define "reluxe.secretName" -}}
{{- .Values.secret.name | default (printf "%s-secret" (include "reluxe.fullname" .)) }}
{{- end }}

{{/*
환경변수 주입 블록.
웹·크롤러·집계·마이그레이션이 전부 같은 설정을 받아야 하므로 한 곳에 둔다.
envFrom 을 쓰면 ConfigMap/Secret 의 키가 그대로 환경변수 이름이 된다.
  LOG_LEVEL 키 → LOG_LEVEL 환경변수
app/config.py 가 os.getenv("LOG_LEVEL") 로 읽으므로 그대로 맞아떨어진다.
*/}}
{{- define "reluxe.envFrom" -}}
- configMapRef:
    name: {{ include "reluxe.configMapName" . }}
- secretRef:
    name: {{ include "reluxe.secretName" . }}
{{- end }}
