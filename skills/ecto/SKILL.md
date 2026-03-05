---
name: ecto
description: Ecto conventions for schemas, changesets, query composition, and migration design. Use when modifying schemas, context queries, constraints, indexes, transactions, or migrations.
---

# Ecto

## Rules

1. Always use changesets for insert/update operations.
2. Preload associations before template access to avoid N+1 queries.
3. Use transactions for multi-step operations that must succeed together.
4. Add database constraints and mirror them in changesets.
5. Keep `Repo` usage inside context modules, not web layer modules.
6. Add indexes for foreign keys and high-frequency query fields.
7. Keep migration changes reversible and explicit.

## Use This Skill When

- Editing schemas, changesets, context query functions, or migrations.
- Designing table constraints and index strategy.
- Reviewing database access boundaries in contexts.

## Workflow

1. Start from schema and changeset rules.
2. Add/update migration for structural changes.
3. Expose operations through context APIs.
4. Add tests for valid and invalid paths.

## References

- `./references/ecto-conventions.md`
- `../elixir/references/project-structure.md`

## Related Skills

- `elixir`
- `testing`
