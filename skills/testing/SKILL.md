---
name: testing
description: Test design rules for contexts, schemas, LiveViews, fixtures, and failure-path coverage. Use when writing or updating any _test.exs file, fixtures, or test support helpers.
---

# Testing

## Rules

1. Use `DataCase` for schema/context tests and `ConnCase` for LiveView/controller tests.
2. Test happy paths and invalid/error paths for every fallible behavior.
3. Add unauthorized/redirect coverage for protected resources.
4. Prefer reusable fixtures in `test/support` over repeated inline setup.
5. For LiveView, prefer `has_element?/2`, `element/2`, and form helpers over brittle raw HTML checks.
6. Keep tests focused on public interfaces and user-visible outcomes.
7. Run targeted tests first, then full suite before finalizing.

## Use This Skill When

- Creating or editing `_test.exs` files.
- Adding coverage for context APIs, LiveViews, schemas, or migrations.
- Refactoring fixture strategy and test helper modules.

## Workflow

1. Define/extend fixtures first.
2. Write the failing test that captures expected behavior.
3. Implement minimum production changes.
4. Add edge/unauthorized/error cases and rerun suite.

## References

- `./references/testing-guide.md`
- `../elixir/references/project-structure.md`

## Related Skills

- `elixir`
- `ecto`
- `phoenix-live-view`
