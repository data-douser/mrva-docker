---
name: develop-helm-chart
description: Agent skill for teaching Helm Chart development following best practices for Helm and Kubernetes.
---

# `develop-helm-chart` Skill

## CHART STRUCTURE

```bash
mychart/
  Chart.yaml          # Chart metadata (name, version, appVersion)
  values.yaml         # Default configuration values
  charts/             # Subchart dependencies
  templates/          # Template files
    _helpers.tpl      # Reusable named templates (partials)
    deployment.yaml   # Kubernetes manifests
    service.yaml
    NOTES.txt         # Post-install instructions
```

## BUILT-IN OBJECTS

| Object | Description |
| ------ | ----------- |
| `.Release.Name` | Release name |
| `.Release.Namespace` | Target namespace |
| `.Release.IsInstall` | True if install operation |
| `.Release.IsUpgrade` | True if upgrade/rollback |
| `.Release.Revision` | Revision number (starts at 1) |
| `.Values` | Values from values.yaml and overrides |
| `.Chart.Name` | Chart name from Chart.yaml |
| `.Chart.Version` | Chart version |
| `.Chart.AppVersion` | Application version |
| `.Files` | Access non-template files |
| `.Capabilities.KubeVersion` | Kubernetes version |
| `$` | Root scope (use inside `with`/`range`) |

## VALUES

Values come from multiple sources (in order of precedence):

1. `--set` flags (highest)
2. `-f` custom values file
3. Parent chart's values.yaml (for subcharts)
4. Chart's values.yaml (lowest)

Access values: `{{ .Values.key.subkey }}`

Delete a default key: `--set key=null`

## TEMPLATE FUNCTIONS

### String Functions

```yaml
{{ .Values.name | quote }}              # Quote string
{{ .Values.name | upper }}              # Uppercase
{{ .Values.name | lower }}              # Lowercase
{{ .Values.name | title }}              # Title case
{{ .Values.name | trunc 63 }}           # Truncate
{{ .Values.name | trimSuffix "-" }}     # Remove suffix
{{ printf "%s-%s" .Release.Name .Chart.Name }}
```

### Default Values

```yaml
{{ .Values.foo | default "bar" }}       # Fallback value
{{ .Values.foo | default (include "mychart.name" .) }}
```

### YAML Handling

```yaml
{{ toYaml .Values.resources | nindent 2 }}   # Convert + indent
{{ .Values.annotations | toYaml | indent 4 }}
```

### Logic Operators

```yaml
{{ if eq .Values.type "server" }}
{{ if ne .Values.env "prod" }}
{{ if and .Values.a .Values.b }}
{{ if or .Values.a .Values.b }}
{{ if not .Values.disabled }}
```

## CONTROL STRUCTURES

### Conditionals

```yaml
{{- if .Values.ingress.enabled }}
# Resource definition here
{{- else }}
# Alternative
{{- end }}
```

Pipeline evaluates as **false** if: boolean false, numeric zero, empty string, nil, empty collection.

### Scope with `with`

```yaml
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

Inside `with`, use `$` to access root: `{{ $.Release.Name }}`

### Loops with `range`

```yaml
# List iteration
{{- range .Values.hosts }}
- {{ . | quote }}
{{- end }}

# With index
{{- range $index, $host := .Values.hosts }}
- {{ $index }}: {{ $host }}
{{- end }}

# Map iteration
{{- range $key, $val := .Values.env }}
{{ $key }}: {{ $val | quote }}
{{- end }}
```

## NAMED TEMPLATES

Define in `_helpers.tpl`:

```yaml
{{- define "mychart.labels" -}}
app.kubernetes.io/name: {{ include "mychart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

Use with `include` (preferred over `template`):

```yaml
metadata:
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
```

**Why `include` over `template`?** `include` returns a string that can be piped to other functions like `nindent`.

### Naming Convention

Prefix template names with chart name to avoid conflicts: `{{ define "mychart.fullname" }}`

## WHITESPACE CONTROL

- `{{-` chomps whitespace **left**
- `-}}` chomps whitespace **right**
- Space required: `{{-` not `{{-`

```yaml
{{- if .Values.enabled }}
key: value
{{- end }}
```

## VARIABLES

```yaml
{{- $relname := .Release.Name -}}
{{- with .Values.favorite }}
release: {{ $relname }}    # Can't use .Release.Name here
drink: {{ .drink }}
{{- end }}
```

## SUBCHARTS AND GLOBALS

Parent chart overrides subchart values via key matching subchart name:

```yaml
# In parent values.yaml
mysubchart:
  key: value
```

Global values accessible everywhere:

```yaml
global:
  imageRegistry: myregistry.com

# Access as: {{ .Values.global.imageRegistry }}
```

## NOTES.txt

Create `templates/NOTES.txt` for post-install instructions:

```text
Thank you for installing {{ .Chart.Name }}.
Release: {{ .Release.Name }}

To verify: helm status {{ .Release.Name }}
```

## DEBUGGING

| Command | Purpose |
| ------- | ------- |
| `helm lint <chart>` | Validate best practices |
| `helm template <name> <chart>` | Render locally |
| `helm template <name> <chart> --debug` | Verbose render |
| `helm install <name> <chart> --dry-run --debug` | Simulate install |
| `helm get manifest <release>` | View installed templates |

Debug a value:

```yaml
{{- printf "%#v" .Values | fail }}
```

Comment out problem sections to isolate errors.

## FILES IN THIS SKILL

- [helm-patterns.md](helm-patterns.md) - Common template patterns and examples
- [troubleshooting.md](troubleshooting.md) - Error resolution guide

## REFERENCES

- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Helm Template Guide](https://helm.sh/docs/chart_template_guide/)
- [Helm Function List](https://helm.sh/docs/chart_template_guide/function_list/)
- [Helm Built-in Objects](https://helm.sh/docs/chart_template_guide/builtin_objects/)
- [Kubernetes Docs](https://kubernetes.io/docs/home/)
