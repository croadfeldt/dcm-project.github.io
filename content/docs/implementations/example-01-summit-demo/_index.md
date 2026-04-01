---
title: "_Index"
type: docs
---

# DCM Example Implementation #1 — Summit Demo

> **This is an example implementation** provided to demonstrate the DCM architecture
> in a working deployment. It is intended as a reference and portability exercise —
> service providers built here may be replaced by production implementations.
> All architectural decisions reference the DCM specification at
> [github.com/dcm-project](https://github.com/dcm-project).

---

## Purpose

This implementation validates the DCM control plane architecture and data model
against three Summit 2026 demonstration use cases:

1. **Intelligent Placement** — policy-governed workload placement using OPA Rego rules
2. **Datacenter Rehydration** — full environment reconstruction from declared state
3. **Application as a Service** — Meta Provider composing VM + Network + OCP Cluster

---

## Technology Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Control Plane | Go services | Lightweight, strong concurrency, cloud-native |
| API Gateway | Go (custom) | Full control over mTLS termination and rate limiting |
| Policy Engine | OPA (CNCF) | Red Hat sanctioned; used in ACM, OpenShift; Rego shown in slides |
| Git Server | GitLab CE | Decision: intent/requested state, policy GitOps store |
| Database | PostgreSQL (CrunchyData PGO) | Decision: Snapshot Store with RLS, OpenShift native |
| Event Bus | AMQ Streams (Kafka) | Red Hat product; reliable event streaming |
| Search | OpenSearch | Red Hat supported OSS |
| Auth | Keycloak (Red Hat SSO) | Red Hat product; OIDC + group membership |
| Secrets | HashiCorp Vault | Credential Provider; widely used in Red Hat ecosystem |
| Service Mesh | OpenShift Service Mesh (Istio) | mTLS between all control plane components |
| Monitoring | Prometheus + Grafana | Standard OpenShift observability stack |
| Frontend | Red Hat Developer Hub (RHDH) | Decision: consumer-facing interface |
| Container Platform | OpenShift | All components run as OpenShift workloads |

---

## Service Providers (Summit Demo)

| Provider | Wraps | Purpose |
|----------|-------|---------|
| `dcm-provider-vm` | Ansible Automation Platform | VM provisioning on target infrastructure |
| `dcm-provider-ocp-cluster` | OpenShift/CAPI | OCP cluster provisioning |
| `dcm-provider-network` | AAP/Ansible | Network port and VLAN provisioning |
| `dcm-provider-acm-shim` | Red Hat ACM API | ACM as standard DCM provider (shim) |
| `dcm-provider-webapp` | Meta Provider | Composes VM + Network + OCP Cluster |

---

## Prerequisites

- OpenShift 4.14+ cluster with cluster-admin access
- Ansible 2.14+ with `kubernetes.core` collection
- OpenShift CLI (`oc`) configured against target cluster
- The following OpenShift Operators available (installed by playbook):
  - Red Hat OpenShift Service Mesh
  - AMQ Streams
  - Crunchy Data PGO (PostgreSQL Operator)
  - Red Hat SSO (Keycloak)

---

## Quick Deploy

```bash
# 1. Configure your cluster connection
export KUBECONFIG=/path/to/kubeconfig

# 2. Set required variables
cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml
# Edit hosts.yml with your cluster details

# 3. Run the full deployment
cd ansible
ansible-playbook site.yml

# 4. Access the demo
# RHDH URL will be printed at end of playbook
```

Full step-by-step instructions: [docs/deployment-guide.md](docs/deployment-guide.md)

---

## Architecture Mapping

How this implementation maps to the DCM specification:
[docs/architecture-mapping.md](docs/architecture-mapping.md)

## Demo Script

Summit demo walkthrough scripts:
[docs/demo-script.md](docs/demo-script.md)

## Building a New Provider

[docs/provider-development-guide.md](docs/provider-development-guide.md)

---

*This is Example Implementation #1 for the DCM project. See the
[DCM architecture documentation](https://github.com/dcm-project) for the
full specification this implementation is based on.*
