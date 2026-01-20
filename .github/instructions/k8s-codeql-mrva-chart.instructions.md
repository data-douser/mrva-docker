---
applyTo: 'k8s/codeql-mrva-chart/**'
description: Instructions for developing and maintaining the 'codeql-mrva-chart' Helm chart for deploying CodeQL MRVA on Kubernetes.
---

# Instructions for `k8s/codeql-mrva-chart/`

## REQUIREMENTS

- Follow [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- Run `helm lint k8s/codeql-mrva-chart` before committing changes
- Use named templates in `_helpers.tpl` for reusable definitions
- Document all values in `values.yaml` with comments
- Use `{{ include }}` over `{{ template }}` for named templates

## CONSTRAINTS

- No trailing whitespace in YAML files
- No hardcoded values—use `values.yaml` for configuration
- Template names must be prefixed with chart name (e.g., `codeql-mrva-chart.fullname`)
- Quote all string values containing special YAML characters

## VALIDATION

```bash
# Lint the chart
helm lint k8s/codeql-mrva-chart
```

## REFERENCES

- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Helm Template Guide](https://helm.sh/docs/chart_template_guide/)
