# Architecture Documentation

Comprehensive documentation about the architecture and design decisions of this Flutter Clean Architecture template.

## Overview

This section covers:
- Why Clean Architecture was chosen
- Architecture layers and their responsibilities
- Design decisions and rationale
- Trade-offs and alternatives
- When to use this template

## Documentation

### Core Architecture

- **[Architecture Overview](overview.md)** - Why Clean Architecture, benefits, trade-offs, when to use, and learning resources
- **[Design Decisions](design-decisions.md)** - Detailed rationale for routing, state management, error handling, logging, storage, and HTTP client choices

### Related Documentation

- **[Understanding the Codebase](../guides/understanding-codebase.md)** - Architecture and code organization
- **[Common Tasks](../guides/common-tasks.md)** - How to add features following Clean Architecture
- **[Adding Features](../api/examples/adding-features.md)** - Step-by-step guide to adding new features
- **[API Documentation](../api/README.md)** - Complete API reference

## Quick Start

New to the architecture? Start here:

1. Read [Architecture Overview](overview.md) to understand why Clean Architecture
2. Review [Design Decisions](design-decisions.md) to understand technical choices
3. Check [Understanding the Codebase](../guides/understanding-codebase.md) for code organization
4. Follow [Common Tasks](../guides/common-tasks.md) to add your first feature

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

