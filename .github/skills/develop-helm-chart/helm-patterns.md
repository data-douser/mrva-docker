# Helm Template Patterns

## Standard Labels Template

Define in `_helpers.tpl`:

```yaml
{{/*
Common labels
*/}}
{{- define "mychart.labels" -}}
helm.sh/chart: {{ include "mychart.chart" . }}
{{ include "mychart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mychart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mychart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

Use with `include`:

```yaml
metadata:
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
```

## Fullname Pattern

```yaml
{{- define "mychart.fullname" -}}
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
```

## Conditionals

```yaml
{{- if .Values.ingress.enabled }}
# resource definition
{{- end }}

{{- if and .Values.persistence.enabled (not .Values.persistence.existingClaim) }}
# create PVC
{{- end }}

{{- if or .Values.env .Values.envFrom }}
# environment config
{{- end }}
```

## Optional Blocks with `with`

```yaml
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}

{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}

{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

## Loops

```yaml
# Simple list
{{- range .Values.hosts }}
- {{ . | quote }}
{{- end }}

# Environment variables from map
env:
{{- range $key, $value := .Values.env }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}

# Container ports
ports:
{{- range .Values.service.ports }}
- name: {{ .name }}
  containerPort: {{ .containerPort }}
  protocol: {{ .protocol | default "TCP" }}
{{- end }}
```

## Image Reference

```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
imagePullPolicy: {{ .Values.image.pullPolicy }}

{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

## Resource Limits

```yaml
{{- if .Values.resources }}
resources:
  {{- toYaml .Values.resources | nindent 2 }}
{{- end }}
```

## Service Account

```yaml
serviceAccountName: {{ include "mychart.serviceAccountName" . }}

# In _helpers.tpl
{{- define "mychart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mychart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
```

## Volume Mounts

```yaml
{{- if .Values.persistence.enabled }}
volumes:
- name: data
  persistentVolumeClaim:
    claimName: {{ .Values.persistence.existingClaim | default (include "mychart.fullname" .) }}
{{- end }}
```

## ConfigMap from Files

```yaml
data:
{{- range $path, $_ := .Files.Glob "config/*" }}
  {{ base $path }}: |-
    {{ $.Files.Get $path | nindent 4 }}
{{- end }}
```

## Secret Data

```yaml
data:
  {{- if .Values.auth.existingSecret }}
  # Using existing secret
  {{- else }}
  password: {{ .Values.auth.password | b64enc | quote }}
  {{- end }}
```

## Resource Limits

```yaml
{{- with .Values.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
```
