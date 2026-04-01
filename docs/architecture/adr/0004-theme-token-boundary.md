# ADR 0004: Theme and Token Boundary

- Status: Proposed
- Date: 2026-03-27

## Context
Theme definitions and design tokens exist in multiple places (`shared/theme` and `shared/design_system/tokens`), risking divergence and inconsistent semantics.

## Decision
Define a single semantic token contract (`AppDesignTokens`) and use it as source-of-truth for theme composition. Keep theme generation (`ThemeData`) as adapter logic on top of tokens.

Prefer `shared/design_system/tokens` as token authority; map legacy theme constants during migration.

## Consequences
### Positive
- Consistent token semantics across UI and design system assets.
- Easier theme scaling (brand/theme variants) with explicit contracts.
- Reduces accidental hardcoded styling in feature widgets.

### Trade-offs
- Requires mapping work and possible token renaming.
- Some temporary duplication while legacy theme references are removed.

## Compatibility Criteria
- Existing `AppTheme.lightTheme` and `AppTheme.darkTheme` remain stable in early migration phases.
- New components must consume semantic tokens through the contract.
