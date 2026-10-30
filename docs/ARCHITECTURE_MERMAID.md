# Batik Architecture Blueprints

> Target architecture. Batik remains a model-agnostic Flutter framework for agent-driven UI; Farabi is one consumer, not a dependency.

## Component architecture

```mermaid
flowchart TB
  Agent["Any Agent / A2UI Producer"] --> Protocol["Validated A2UI Protocol"]
  Protocol --> Parser["Node Parser and Schema Validation"]
  Parser --> Tree["Declarative UI Node Tree"]
  Tree --> Registry["Component Registry"]
  Registry --> Native["Built-in Flutter Widgets"]
  Registry --> Extensions["Third-party Extensions"]
  Extensions --> Farabi["Optional Farabi Dashboard Adapter"]
  Extensions --> Charts["Optional Chart Adapters"]
  Tree --> Actions["Permissioned Action Dispatcher"]
  Actions --> Host["Host Application / Agent"]
```

## UI update and action sequence

```mermaid
sequenceDiagram
  participant Agent as Agent Producer
  participant Host as Host App
  participant Batik as Batik Runtime
  participant Widget as Flutter Widget
  Agent->>Host: Declarative UI payload
  Host->>Batik: Submit payload with trusted context
  Batik->>Batik: Validate schema and bounds
  Batik->>Widget: Build registered components
  Widget-->>Host: User interaction
  Host->>Host: Authorize action
  Host-->>Agent: Permitted event only
```

## Component lifecycle

```mermaid
stateDiagram-v2
  [*] --> Received
  Received --> Rejected: Invalid schema
  Received --> Validated: Schema and limits pass
  Validated --> Rendered: Registry resolves nodes
  Rendered --> Updated: Valid incremental update
  Updated --> Rendered
  Rendered --> Disposed
  Rejected --> [*]
  Disposed --> [*]
```

## Architectural rules

- Core widgets and A2UI contracts must remain agnostic to Farabi, Toba, and any one model provider.
- Custom extensions are registered through stable APIs; unknown components fail safely.
- UI actions are requests, never authority to execute privileged operations.
- Validate payload depth, size, allowed actions, and resource usage.
- Preserve accessibility, lifecycle cleanup, testability and Flutter compatibility.
