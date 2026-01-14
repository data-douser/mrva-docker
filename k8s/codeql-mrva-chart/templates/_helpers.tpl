{{/*
Expand the name of the chart.
*/}}
{{- define "codeql-mrva-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "codeql-mrva-chart.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "codeql-mrva-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "codeql-mrva-chart.labels" -}}
helm.sh/chart: {{ include "codeql-mrva-chart.chart" . }}
{{ include "codeql-mrva-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "codeql-mrva-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "codeql-mrva-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "codeql-mrva-chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "codeql-mrva-chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Global annotations
*/}}
{{- define "codeql-mrva-chart.annotations" -}}
{{- with .Values.global.annotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Image pull secrets
*/}}
{{- define "codeql-mrva-chart.imagePullSecrets" -}}
{{- with .Values.global.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/* ==========================================================================
    Service-specific name helpers
    ========================================================================== */}}

{{/*
Server component name
*/}}
{{- define "codeql-mrva-chart.server.fullname" -}}
{{- printf "%s-server" (include "codeql-mrva-chart.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Server labels
*/}}
{{- define "codeql-mrva-chart.server.labels" -}}
{{ include "codeql-mrva-chart.labels" . }}
app.kubernetes.io/component: server
{{- end }}

{{/*
Server selector labels
*/}}
{{- define "codeql-mrva-chart.server.selectorLabels" -}}
{{ include "codeql-mrva-chart.selectorLabels" . }}
app.kubernetes.io/component: server
{{- end }}

{{/*
Agent component name
*/}}
{{- define "codeql-mrva-chart.agent.fullname" -}}
{{- printf "%s-agent" (include "codeql-mrva-chart.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Agent labels
*/}}
{{- define "codeql-mrva-chart.agent.labels" -}}
{{ include "codeql-mrva-chart.labels" . }}
app.kubernetes.io/component: agent
{{- end }}

{{/*
Agent selector labels
*/}}
{{- define "codeql-mrva-chart.agent.selectorLabels" -}}
{{ include "codeql-mrva-chart.selectorLabels" . }}
app.kubernetes.io/component: agent
{{- end }}

{{/*
HEPC component name
*/}}
{{- define "codeql-mrva-chart.hepc.fullname" -}}
{{- printf "%s-hepc" (include "codeql-mrva-chart.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
HEPC labels
*/}}
{{- define "codeql-mrva-chart.hepc.labels" -}}
{{ include "codeql-mrva-chart.labels" . }}
app.kubernetes.io/component: hepc
{{- end }}

{{/*
HEPC selector labels
*/}}
{{- define "codeql-mrva-chart.hepc.selectorLabels" -}}
{{ include "codeql-mrva-chart.selectorLabels" . }}
app.kubernetes.io/component: hepc
{{- end }}

{{/*
PostgreSQL component name
*/}}
{{- define "codeql-mrva-chart.postgres.fullname" -}}
{{- printf "%s-postgres" (include "codeql-mrva-chart.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
PostgreSQL labels
*/}}
{{- define "codeql-mrva-chart.postgres.labels" -}}
{{ include "codeql-mrva-chart.labels" . }}
app.kubernetes.io/component: postgres
{{- end }}

{{/*
PostgreSQL selector labels
*/}}
{{- define "codeql-mrva-chart.postgres.selectorLabels" -}}
{{ include "codeql-mrva-chart.selectorLabels" . }}
app.kubernetes.io/component: postgres
{{- end }}

{{/*
MinIO component name
*/}}
{{- define "codeql-mrva-chart.minio.fullname" -}}
{{- printf "%s-minio" (include "codeql-mrva-chart.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
MinIO labels
*/}}
{{- define "codeql-mrva-chart.minio.labels" -}}
{{ include "codeql-mrva-chart.labels" . }}
app.kubernetes.io/component: minio
{{- end }}

{{/*
MinIO selector labels
*/}}
{{- define "codeql-mrva-chart.minio.selectorLabels" -}}
{{ include "codeql-mrva-chart.selectorLabels" . }}
app.kubernetes.io/component: minio
{{- end }}

{{/*
RabbitMQ component name
*/}}
{{- define "codeql-mrva-chart.rabbitmq.fullname" -}}
{{- printf "%s-rabbitmq" (include "codeql-mrva-chart.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
RabbitMQ labels
*/}}
{{- define "codeql-mrva-chart.rabbitmq.labels" -}}
{{ include "codeql-mrva-chart.labels" . }}
app.kubernetes.io/component: rabbitmq
{{- end }}

{{/*
RabbitMQ selector labels
*/}}
{{- define "codeql-mrva-chart.rabbitmq.selectorLabels" -}}
{{ include "codeql-mrva-chart.selectorLabels" . }}
app.kubernetes.io/component: rabbitmq
{{- end }}

{{/*
Code Server component name
*/}}
{{- define "codeql-mrva-chart.codeserver.fullname" -}}
{{- printf "%s-codeserver" (include "codeql-mrva-chart.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Code Server labels
*/}}
{{- define "codeql-mrva-chart.codeserver.labels" -}}
{{ include "codeql-mrva-chart.labels" . }}
app.kubernetes.io/component: codeserver
{{- end }}

{{/*
Code Server selector labels
*/}}
{{- define "codeql-mrva-chart.codeserver.selectorLabels" -}}
{{ include "codeql-mrva-chart.selectorLabels" . }}
app.kubernetes.io/component: codeserver
{{- end }}

{{/*
gh-mrva component name
*/}}
{{- define "codeql-mrva-chart.ghmrva.fullname" -}}
{{- printf "%s-ghmrva" (include "codeql-mrva-chart.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
gh-mrva labels
*/}}
{{- define "codeql-mrva-chart.ghmrva.labels" -}}
{{ include "codeql-mrva-chart.labels" . }}
app.kubernetes.io/component: ghmrva
{{- end }}

{{/*
gh-mrva selector labels
*/}}
{{- define "codeql-mrva-chart.ghmrva.selectorLabels" -}}
{{ include "codeql-mrva-chart.selectorLabels" . }}
app.kubernetes.io/component: ghmrva
{{- end }}

{{/* ==========================================================================
    Service endpoint helpers
    ========================================================================== */}}

{{/*
PostgreSQL host - returns internal service name or external host
*/}}
{{- define "codeql-mrva-chart.postgres.host" -}}
{{- if .Values.postgres.enabled }}
{{- include "codeql-mrva-chart.postgres.fullname" . }}
{{- else }}
{{- .Values.postgres.external.host }}
{{- end }}
{{- end }}

{{/*
PostgreSQL port
*/}}
{{- define "codeql-mrva-chart.postgres.port" -}}
{{- if .Values.postgres.enabled }}
{{- .Values.postgres.service.port }}
{{- else }}
{{- .Values.postgres.external.port }}
{{- end }}
{{- end }}

{{/*
HEPC endpoint URL
*/}}
{{- define "codeql-mrva-chart.hepc.endpoint" -}}
{{- if .Values.hepc.enabled }}
{{- printf "http://%s:%v" (include "codeql-mrva-chart.hepc.fullname" .) .Values.hepc.service.port }}
{{- else }}
{{- .Values.hepc.externalEndpoint }}
{{- end }}
{{- end }}

{{/*
MinIO endpoint URL
*/}}
{{- define "codeql-mrva-chart.minio.endpoint" -}}
{{- printf "http://%s:%v" (include "codeql-mrva-chart.minio.fullname" .) .Values.minio.service.port }}
{{- end }}

{{/*
RabbitMQ host
*/}}
{{- define "codeql-mrva-chart.rabbitmq.host" -}}
{{- include "codeql-mrva-chart.rabbitmq.fullname" . }}
{{- end }}

{{/*
Server host
*/}}
{{- define "codeql-mrva-chart.server.host" -}}
{{- include "codeql-mrva-chart.server.fullname" . }}
{{- end }}

{{/*
ConfigMap name
*/}}
{{- define "codeql-mrva-chart.configmapName" -}}
{{- printf "%s-config" (include "codeql-mrva-chart.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Secret name
*/}}
{{- define "codeql-mrva-chart.secretName" -}}
{{- printf "%s-secrets" (include "codeql-mrva-chart.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
