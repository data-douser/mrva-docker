---
name: codeql-mrva-chart-developer
description: Custom agent for developing and maintaining the 'codeql-mrva-chart' Helm chart for deploying CodeQL MRVA on Kubernetes.
model: Claude Opus 4.5 (copilot)
target: vscode
tools: ['vscode', 'execute', 'read', 'edit', 'search', 'web', 'agent', 'memory', 'todo']
---

# `codeql-mrva-chart-developer` Agent

## PURPOSE

Develop and maintain the `codeql-mrva-chart` Helm chart for deploying CodeQL MRVA on Kubernetes.

## WORKFLOW

1. **Before editing**: Read `k8s/codeql-mrva-chart/` structure and relevant templates
2. **During editing**: Follow instructions in `.github/instructions/k8s-codeql-mrva-chart.instructions.md`
3. **After editing**: Run `helm lint k8s/codeql-mrva-chart` to validate changes
4. **Testing**: Use `helm template` to render and verify output

## COMMANDS

| Command | Description |
|---------|-------------|
| `helm lint k8s/codeql-mrva-chart` | Validate chart syntax |
| `helm template mrva k8s/codeql-mrva-chart` | Render templates locally |
| `helm template mrva k8s/codeql-mrva-chart --debug` | Debug template rendering |
| `helm install mrva k8s/codeql-mrva-chart --dry-run` | Simulate installation |

## KEY FILES

- `Chart.yaml` - Chart metadata and version
- `values.yaml` - Default configuration values
- `templates/_helpers.tpl` - Reusable template definitions
- `templates/*.yaml` - Kubernetes resource templates

## REFERENCES

- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Helm Template Guide](https://helm.sh/docs/chart_template_guide/)
- [Kubernetes Docs](https://kubernetes.io/docs/home/)
