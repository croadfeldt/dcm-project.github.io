---
title: Architecture
type: docs
weight: 1
sidebar:
  open: true
---

# DCM Architecture

The DCM architecture is documented across three layers:

{{< cards >}}
  {{< card link="data-model" title="Data Model" icon="database" subtitle="55 documents covering all entity types, four states, policies, providers, and lifecycle management." >}}
  {{< card link="specifications" title="Specifications" icon="document-text" subtitle="15 specification documents: Consumer API, Admin API, Operator Interface, OPA Integration, Flow GUI, and more." >}}
  {{< card link="ai-prompt" title="AI Prompt" icon="chip" subtitle="Full project context for AI models — 103 sections covering all architecture decisions." >}}
{{< /cards >}}

---

## Architecture in One Sentence

DCM is built on three foundational abstractions — **Data**, **Provider**, and **Policy** — connected by a policy-driven event loop. Every concept maps to one of these three. See [00-foundations.md](data-model/00-foundations.md).

---

## Key Numbers

| | |
|-|-|
| Data model documents | 55 |
| Specification documents | 15 |
| API paths | 63 consumer · 57 admin · 5 operator · 7 provider callback |
| Capabilities | 299 across 38 domains |
| Provider types | 11 |
| Policy types | 7 |
| Unresolved architectural questions | 0 |
