---
name: elixir
description: Core Elixir coding rules for pattern matching, callbacks, and tuple-based contracts. Use when editing .ex/.exs modules, refactoring control flow, or defining function contracts and callback implementations.
---

# Elixir

## Rules

1. Use pattern matching and multi-clause functions over nested conditionals.
2. Add `@impl true` before callback implementations.
3. Return tagged tuples (`{:ok, value}` / `{:error, reason}`) for fallible operations.
4. Use `with` for multi-step fallible flows.
5. Prefer pipe chains for sequential transformations.
6. Predicate functions end with `?`; dangerous functions end with `!`.
7. Avoid defensive coding for impossible states; let supervision handle crashes.

## Use This Skill When

- Editing any `.ex` or `.exs` file.
- Refactoring control flow, tuple contracts, or callback implementations.
- Writing reusable core logic that should remain web-framework agnostic.

## Workflow

1. Confirm function contracts and callback requirements.
2. Implement with pattern matching first, then `with`/`case` where needed.
3. Keep modules small and focused; one module per file.
4. Validate behavior with focused tests.

## References

- `./references/project-structure.md`

## Related Skills

- `ecto`
- `phoenix-live-view`
- `testing`
