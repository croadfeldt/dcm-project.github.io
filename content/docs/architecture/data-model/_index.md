---
title: Data Model
type: docs
weight: 2
sidebar:
  open: true
---

# DCM Data Model

The DCM Data Model is the foundational layer that governs how all data in DCM is
represented, versioned, assembled, and governed. It is the single source of truth
for all resources across the full lifecycle — from consumer intent through
realization, operation, and decommission.

{{< cards >}}
  {{< card link="context-and-purpose" title="Context and Purpose" icon="information-circle" subtitle="Why the data model exists, core principles, field-level provenance, and the artifact metadata standard." >}}
  {{< card link="four-states" title="Four States" icon="arrows-expand" subtitle="Intent, Requested, Realized, and Discovered states. Rehydration, drift detection, and CI/CD integration." >}}
  {{< card link="layering-and-versioning" title="Data Layers and Assembly" icon="collection" subtitle="Layer types, assembly process, override control, Layer Domain/Handle/Priority, and conflict detection." >}}
  {{< card link="resource-type-hierarchy" title="Resource Type Hierarchy" icon="cube" subtitle="The Resource Type Registry, catalog model, portability classification, and provider hierarchy." >}}
  {{< card link="resource-service-entities" title="Resource and Service Entities" icon="server" subtitle="Entity definitions, ownership models, lifecycle states, and process resources." >}}
  {{< card link="service-dependencies" title="Service Dependencies" icon="share" subtitle="Dependency rehydration ordering and failure handling on the entity relationship graph." >}}
  {{< card link="resource-grouping" title="Resource Grouping" icon="user-group" subtitle="Tenant model, Resource Groups, grouping model, and multi-tenancy." >}}
  {{< card link="entity-relationships" title="Entity Relationships" icon="link" subtitle="Universal bidirectional relationship model for all entity connections — internal and external." >}}
  {{< card link="information-providers" title="Information Providers" icon="globe" subtitle="External data providers, information types, lookup model, and verification." >}}
  {{< card link="storage-providers" title="Storage Providers" icon="archive" subtitle="Storage provider contracts for GitOps stores, event streams, audit, and observability." >}}
  {{< card link="audit-provenance-observability" title="Audit, Provenance, and Observability" icon="eye" subtitle="The three distinct concerns of audit, data lineage, and operational observability." >}}
{{< /cards >}}
