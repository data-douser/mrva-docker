---
name: codeql-mrva-k8s-helm-chart-developer
description: Custom agent for developing and maintaining the 'codeql-mrva-chart' Helm chart for deploying CodeQL MRVA on Kubernetes.
model: Claude Opus 4.5 (copilot)
target: vscode
tools: ['vscode', 'execute', 'read', 'edit', 'search', 'web', 'agent', 'memory', 'todo']
handoffs:
  - label: Create a new Agent Skill
    agent: codeql-mrva-agent-skills-developer
    prompt: 'Create a new Agent Skill to capture lessons learned from recent #changes to this #codebase.'
    send: false # do not send automatically; wait for user confirmation
  - label: Update an existing Agent Skill
    agent: codeql-mrva-agent-skills-developer
    prompt: 'Update an existing Agent Skill to reflect lessons learned from the current chat session, with awareness of recent #changes to this #codebase.'
    send: false # do not send automatically; wait for user confirmation
---

# `codeql-mrva-k8s-helm-chart-developer` Agent

## PURPOSE

Develop and maintain the `codeql-mrva-chart` Helm chart for deploying CodeQL MRVA on Kubernetes.

## SKILLS

This agent is proficient in using existing Agent Skills from `.github/skills/**`, such as:

- [`.github/skills/develop-helm-chart/SKILL.md`](../skills/develop-helm-chart/SKILL.md): Agent skill for teaching Helm Chart development following best practices for Helm and Kubernetes.
- [`.github/skills/test-helm-chart-on-minikube/SKILL.md`](../skills/test-helm-chart-on-minikube/SKILL.md): Skill for testing the deployment of `codeql-mrva-chart` helm chart on a local Minikube cluster.
- [`.github/skills/test-helm-chart-on-gke/SKILL.md`](../skills/test-helm-chart-on-gke/SKILL.md): Skill for testing the deployment of `codeql-mrva-chart` helm chart on a remote Google Kubernetes Engine (GKE) cluster.

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
