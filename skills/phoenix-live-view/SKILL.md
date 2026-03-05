---
name: phoenix-live-view
description: LiveView lifecycle and UI state patterns for callbacks, forms, streams, and navigation. Use when creating or editing LiveView modules, HEEx templates, or event-driven UI flows.
---

# Phoenix LiveView

## Rules

1. Add `@impl true` on `mount`, `handle_event`, `handle_info`, `handle_params`, and `render`.
2. Initialize all assigns in `mount/3` before they are used in templates.
3. Guard side effects (`PubSub`, timers, subscriptions) with `connected?(socket)`.
4. Return correct callback tuples (`{:ok, socket}` / `{:noreply, socket}`).
5. Keep LiveViews thin and delegate business/data logic to contexts.
6. Use `to_form/2` and `<.input>` for forms; avoid legacy APIs.
7. Use LiveView streams for dynamic collections where appropriate.

## Use This Skill When

- Editing any LiveView module or `.heex` template.
- Adding form flows, stream updates, or URL patch/navigate behavior.
- Debugging lifecycle issues between disconnected and connected mount phases.

## Workflow

1. Set up route and LiveView with clear callback contracts.
2. Initialize assigns and form state in mount.
3. Implement events with context calls and explicit error handling.
4. Render with stable IDs and testable selectors.

## References

- `./references/liveview-checklist.md`
- `../elixir/references/project-structure.md`

## Related Skills

- `elixir`
- `testing`
- `phoenix-uploads`
