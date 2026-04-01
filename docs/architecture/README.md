# Architecture Documentation

Comprehensive documentation about the architecture and design decisions of this Flutter Clean Architecture template.

## Overview

This section covers:
- Why Clean Architecture was chosen
- Architecture layers and their responsibilities
- Design decisions and rationale
- Trade-offs and alternatives
- When to use this template

## Architecture diagram (data flow)

The diagram below shows the “happy path” request flow from **UI → Riverpod → Use case → Repository → Remote data source → API**, and how results come back up.

```mermaid
flowchart LR
  UI[Presentation<br/>Screens / Widgets] --> RP[Riverpod<br/>Providers / Notifiers]
  RP --> UC[Domain<br/>Use cases]
  UC --> REPO[Domain contract<br/>Repository interface]
  REPO --> REPOIMPL[Data<br/>Repository implementation]

  REPOIMPL --> RDS[Data<br/>Remote data source]
  REPOIMPL --> LDS[Data<br/>Local data source]

  RDS --> APIC[Core<br/>ApiClient (Dio facade)]
  APIC --> NET[Core<br/>DioNetworkClient]
  NET --> API[(Backend API)]

  LDS --> STORE[Core<br/>Storage adapters]

  API --> NET --> APIC --> RDS --> REPOIMPL --> UC --> RP --> UI

  RP -. emits state .-> UI
```

Notes:
- **Contracts live in Domain/Core**: UI depends on providers, providers depend on use cases, use cases depend on repository contracts, and implementations live in Data/Core adapters.
- **Replaceable integrations**: you can swap storage/network/auth/RASP implementations via providers/contracts without changing domain logic.

## Documentation

### Core Architecture

- **[Super starter hub](super-starter-hub.md)** - One-page map of capabilities and deep links
- **[Choose your stack](choose-your-stack.md)** - Default stack vs replacing implementations (Path A / Path B)
- **[Architecture Overview](overview.md)** - Why Clean Architecture, benefits, trade-offs, when to use, and learning resources
- **[Design Decisions](design-decisions.md)** - Detailed rationale for routing, state management, error handling, logging, storage, and HTTP client choices
- **[ADRs](adr/README.md)** - Decoupling decisions for network, storage, navigation, theme tokens, and state boundaries
- **[Contracts Map](contracts-map.md)** - Contract files, swap table, optional modules, adapter placement
- **[Migration Guides](migrations/README.md)** - Incremental rollout plans, quality gates, and risk controls

### Related Documentation

- **[Understanding the Codebase](../guides/onboarding/understanding-codebase.md)** - Architecture and code organization
- **[Common Tasks](../guides/features/common-tasks.md)** - How to add features following Clean Architecture
- **[Adding Features](../api/examples/adding-features.md)** - Step-by-step guide to adding new features
- **[API Documentation](../api/README.md)** - Complete API reference

## Quick Start

New to the architecture? Start here:

1. Read [Architecture Overview](overview.md) to understand why Clean Architecture
2. Review [Design Decisions](design-decisions.md) to understand technical choices
3. Check [Understanding the Codebase](../guides/onboarding/understanding-codebase.md) for code organization
4. Follow [Common Tasks](../guides/features/common-tasks.md) to add your first feature

## Architecture Layers

```
┌─────────────────────────────────────┐
│   Presentation Layer (UI)           │
│  - Screens, Widgets, Providers     │
│  - State Management (Riverpod)      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Domain Layer                   │
│  - Entities, Use Cases, Repositories │
│  - Business Logic (Framework-free)   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Data Layer                     │
│  - Models, Data Sources, Repository  │
│  - Implementations                   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Core Layer                     │
│  - Network, Storage, Config, Utils   │
└─────────────────────────────────────┘
```

For detailed information, see [Architecture Overview](overview.md).


