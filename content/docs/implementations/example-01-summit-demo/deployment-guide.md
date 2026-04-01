---
title: "Deployment Guide"
type: docs
---

# Deployment Guide — DCM Example Implementation #1

Step-by-step guide to deploy the DCM Summit Demo on an OpenShift cluster.

---

## Prerequisites

**Cluster requirements:**
- OpenShift 4.14+
- Cluster-admin access
- Minimum 16 vCPUs / 32GB RAM available for DCM workloads
- Default StorageClass configured for dynamic PVC provisioning

**Local tooling:**
```bash
# Verify oc CLI
oc version

# Verify Ansible
ansible --version   # 2.14+
ansible-galaxy collection install kubernetes.core

# Verify Helm (used for some chart installs)
helm version

# Verify KUBECONFIG is set
oc whoami
```

**External dependencies:**
- Ansible Automation Platform (AAP) instance accessible from the cluster — for VM + Network providers
- Red Hat ACM hub cluster — for ACM shim provider (or disable if not available)

---

## Step 1: Configure Inventory

```bash
cd ansible
cp inventory/hosts.yml.example inventory/hosts.yml
# Edit hosts.yml and set cluster_domain to your OpenShift apps domain
# Example: cluster_domain: "apps.ocp.example.com"
```

---

## Step 2: Install Required Operators

This step installs all OperatorHub operators. Requires cluster-admin.

```bash
ansible-playbook site.yml -i inventory/hosts.yml --tags operators
```

Wait for operators to reach `Succeeded` phase (~5-10 min):
```bash
oc get csv -n openshift-operators
```

---

## Step 3: Deploy Storage Stack

```bash
ansible-playbook site.yml -i inventory/hosts.yml --tags storage
```

This deploys:
- PostgreSQL cluster (CrunchyData PGO) — ~3 min to be ready
- AMQ Streams Kafka cluster — ~5 min to be ready
- GitLab CE — ~5 min to be ready (first start is slow)
- OpenSearch — ~2 min

Verify:
```bash
oc get postgrescluster -n dcm-summit-demo
oc get kafka -n dcm-summit-demo
```

---

## Step 4: Deploy Auth and Vault

```bash
ansible-playbook site.yml -i inventory/hosts.yml --tags auth,vault
```

This:
1. Deploys Keycloak and imports the DCM realm
2. Deploys Vault and runs the bootstrap sequence (doc 49 §6)
3. Creates per-provider Vault policies and Kubernetes auth roles

**Important:** The bootstrap admin password is `CHANGE_ME_BOOT002`.
Per BOOT-002, this MUST be rotated on first login:
```bash
# Get Keycloak URL
oc get route -n dcm-summit-demo | grep keycloak
# Login as platform-admin / CHANGE_ME_BOOT002
# Change password immediately
```

---

## Step 5: Configure Service Mesh

```bash
ansible-playbook site.yml -i inventory/hosts.yml --tags service-mesh
```

This installs OpenShift Service Mesh and configures STRICT mTLS across all
DCM components. After this step, all inter-component traffic is encrypted
and authenticated using mutual TLS certificates issued by the mesh CA.

---

## Step 6: Deploy Control Plane

```bash
ansible-playbook site.yml -i inventory/hosts.yml --tags control-plane
```

Verify all control plane pods are running:
```bash
oc get pods -n dcm-summit-demo | grep -E 'api-gateway|orchestrator|policy|placement|processor|audit|catalog|discovery'
```

---

## Step 7: Deploy Service Providers

```bash
ansible-playbook site.yml -i inventory/hosts.yml --tags providers
```

Each provider registers itself with the DCM API Gateway on startup via:
```
POST /api/v1/admin/providers
```

Verify provider registration:
```bash
TOKEN=$(oc get secret dcm-admin-token -n dcm-summit-demo -o jsonpath='{.data.token}' | base64 -d)
DCM_URL=$(oc get route dcm-api-gateway -n dcm-summit-demo -o jsonpath='{.spec.host}')
curl -H "Authorization: Bearer $TOKEN" https://$DCM_URL/api/v1/admin/providers
```

---

## Step 8: Deploy Frontend (RHDH)

```bash
ansible-playbook site.yml -i inventory/hosts.yml --tags rhdh
```

---

## Step 9: Load Seed Data

```bash
ansible-playbook site.yml -i inventory/hosts.yml --tags seed-data
```

This loads:
- Core Layers (US East 1, US West 2)
- Catalog items (VM Standard, OCP Cluster, Web App Meta)
- OPA policies (in shadow mode — review before activating)

---

## Step 10: Activate Policies

Policies are loaded in shadow mode (doc 14 — FCM-004). Review shadow evaluation
results before activating:

```bash
# Check shadow evaluation results in the Policy Engine
curl -H "Authorization: Bearer $TOKEN" https://$DCM_URL/api/v1/admin/policies?status=shadow

# Activate when ready
curl -X POST -H "Authorization: Bearer $TOKEN" \
  https://$DCM_URL/api/v1/admin/policies/{uuid}:activate
```

---

## Full Deployment (Single Command)

```bash
cd ansible
ansible-playbook site.yml -i inventory/hosts.yml
```

Deployment takes approximately 20-30 minutes end-to-end.

---

## Verification

```bash
# Health check
curl https://$(oc get route dcm-api-gateway -n dcm-summit-demo -o jsonpath='{.spec.host}')/livez

# List catalog items (authenticated)
curl -H "Authorization: Bearer $TOKEN" \
  https://$(oc get route dcm-api-gateway -n dcm-summit-demo -o jsonpath='{.spec.host}')/api/v1/catalog
```

---

## Teardown

```bash
oc delete namespace dcm-summit-demo
```
