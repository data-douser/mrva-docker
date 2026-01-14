# Helm Troubleshooting Guide

## Validation Commands

```bash
# Lint for errors and best practices
helm lint <chart-path>

# Render templates locally
helm template <release-name> <chart-path>

# Debug with verbose output
helm template <release-name> <chart-path> --debug

# Dry-run install (checks cluster conflicts)
helm install <release-name> <chart-path> --dry-run --debug

# Dry-run with server-side validation and lookup
helm install <release-name> <chart-path> --dry-run=server

# Render specific template only
helm template <release-name> <chart-path> -s templates/deployment.yaml

# View installed manifest
helm get manifest <release-name>
```

## Common Errors

### YAML Parsing Errors

**Symptom**: `error converting YAML to JSON`

**Causes**:
- Trailing whitespace
- Incorrect indentation
- Missing quotes on special characters
- Tabs instead of spaces

**Fix**: Check indentation, use `| nindent N` for multi-line values.

### Template Function Errors

**Symptom**: `function "X" not defined`

**Fix**: Check function name spelling. Common mistakes:
- `indent` vs `nindent` (nindent adds newline first)
- Use `include` not `template` when piping to functions

### Nil Pointer Errors

**Symptom**: `nil pointer evaluating interface`

**Cause**: Accessing undefined value path like `.Values.foo.bar` when `foo` doesn't exist.

**Fixes**:
```yaml
# Guard with if
{{- if .Values.foo }}
  bar: {{ .Values.foo.bar }}
{{- end }}

# Use default
{{ .Values.foo | default "value" }}

# Use with for nested access
{{- with .Values.foo }}
  bar: {{ .bar }}
{{- end }}
```

### Name Too Long

**Symptom**: `must be no more than 63 characters`

**Cause**: Kubernetes DNS naming limits.

**Fix**: Always truncate generated names:
```yaml
name: {{ include "mychart.fullname" . | trunc 63 | trimSuffix "-" }}
```

### Scope Issues in `with`/`range`

**Symptom**: `can't evaluate field Release in type interface {}`

**Cause**: Inside `with` or `range`, `.` changes scope.

**Fix**: Use `$` for root scope:
```yaml
{{- with .Values.config }}
release: {{ $.Release.Name }}
value: {{ .key }}
{{- end }}
```

### Empty Output

**Symptom**: Template produces nothing or `null`

**Causes**:
- Conditional evaluates false
- Value is empty/nil
- Wrong indentation with `{{-`

**Debug**: Check what value actually is:
```yaml
{{- printf "%#v" .Values.mykey | fail }}
```

### Whitespace Issues

**Symptom**: Malformed YAML, extra blank lines, or concatenated values

**Cause**: `{{-` or `-}}` used incorrectly.

**Examples**:
```yaml
# Wrong: produces "food: PIZZAmug: true"
food: {{ .Values.food }}{{- if .Values.mug }}
mug: {{ .Values.mug }}{{- end }}

# Correct
food: {{ .Values.food }}
{{- if .Values.mug }}
mug: {{ .Values.mug }}
{{- end }}
```

### Indentation in Lists

**Symptom**: YAML list items not properly indented

**Fix**: Use `nindent` (not `indent`) for lists:
```yaml
tolerations:
  {{- toYaml .Values.tolerations | nindent 2 }}
```

## Debug Techniques

### Print and Fail

```yaml
# Print value structure and stop
{{- printf "%#v" .Values | fail }}

# Print specific value
{{- printf "DEBUG: %v" .Values.key | fail }}
```

### Comment Out Problem Sections

```yaml
apiVersion: v1
kind: ConfigMap
# Commenting out problem area
# data:
#   key: {{ .Values.problematic }}
```

### Override Values for Testing

```bash
# Single value
helm template test ./mychart --set key=value

# Multiple values
helm template test ./mychart --set a=1,b=2

# From file
helm template test ./mychart -f test-values.yaml
```

### Check Value Sources

```bash
# Show computed values
helm template test ./mychart --debug 2>&1 | grep -A 50 "COMPUTED VALUES"
```

## Best Practice Checklist

- [ ] Run `helm lint` before commits
- [ ] Test with `--dry-run --debug`
- [ ] Use `nindent` for consistent indentation
- [ ] Always truncate names to 63 chars
- [ ] Quote strings with special characters
- [ ] Guard optional nested values with `if` or `with`
- [ ] Use `$` inside `with`/`range` for root access
- [ ] Document all values in values.yaml
