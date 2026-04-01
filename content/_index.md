---
title: DCM Project
toc: false
---

# Data Center Management

**Hyperscaler-like cloud experience for enterprise on-premises and sovereign cloud infrastructure.**

DCM is an open-source governing framework that gives enterprise IT organizations the operational 
model and self-service capabilities of a public cloud provider — on infrastructure they own and control.

{{< button href="/docs/project-overview" >}}What is DCM?{{< /button >}}
{{< button href="/docs" >}}Documentation{{< /button >}}
{{< button href="/docs/implementations" >}}Implementations{{< /button >}}
{{< button href="https://github.com/dcm-project" >}}GitHub{{< /button >}}

---

## The Problem DCM Solves

Enterprise on-premises infrastructure is managed by dozens of disconnected tools and manual 
processes. A single VM can take weeks across five teams. No one has a trustworthy answer to: 
*what exists, what was requested, what was provisioned, and does current state match intended state?*

DCM establishes a unified, declarative single source of truth for all infrastructure state 
and connects it to a policy-driven control plane that governs every lifecycle operation.

## Three Foundational Abstractions

{{< cards >}}
  {{< card title="Data" icon="database" subtitle="Every artifact with a UUID, lifecycle state, and field-level provenance. Four states: Intent · Requested · Realized · Discovered." >}}
  {{< card title="Provider" icon="plug" subtitle="11 typed provider contracts. Service, Information, Storage, Meta, Credential, Auth, Policy, Notification, Message Bus, ITSM, Peer DCM." >}}
  {{< card title="Policy" icon="shield-check" subtitle="7 typed policy schemas. GateKeeper · Validation · Transformation · Orchestration Flow · Recovery · Governance Matrix · Lifecycle." >}}
{{< /cards >}}

## Who Benefits

{{< cards >}}
  {{< card title="Application Teams" icon="users" subtitle="Self-service catalog. Request infrastructure. Receive provisioned resources. No tickets, no manual coordination." >}}
  {{< card title="Platform Engineers" icon="cog" subtitle="Single control plane. Policy-governed standards. Automatic drift detection. Consistency is structural." >}}
  {{< card title="Security & Compliance" icon="lock-closed" subtitle="Policy-as-code tested before activation. Tamper-evident audit trail. Continuous accreditation monitoring." >}}
  {{< card title="Regulated Industries" icon="building-library" subtitle="FedRAMP · CMMC · HIPAA · SOC 2 · ISO 27001 · DoD IL2–IL6. Compliance by construction." >}}
{{< /cards >}}

---

## Explore

{{< cards >}}
  {{< card link="docs/project-overview" title="Project Overview" icon="information-circle" subtitle="What DCM is, what it does, who it benefits, where it operates." >}}
  {{< card link="docs/architecture" title="Architecture" icon="template" subtitle="55 data model docs · 15 specs · 299 capabilities across 38 domains." >}}
  {{< card link="docs/implementations" title="Implementations" icon="rocket-launch" subtitle="Reference implementations. Example #1: Summit 2026 demo on OpenShift." >}}
  {{< card link="https://github.com/dcm-project" title="GitHub" icon="code-bracket" subtitle="Source, issues, and contributions." >}}
{{< /cards >}}
