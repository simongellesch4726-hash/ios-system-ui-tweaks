# iOS26UI research plan

## Scope

A separate SpringBoard UI package covering:

- Dock appearance and layout
- Search placement immediately above the Dock
- scroll-indicator visibility behavior
- related transitions and animations

## Required execution-path trace

### Dock/Search

1. Home Screen controller hierarchy.
2. Dock view ownership and layout pass.
3. Search view ownership and placement constraints.
4. Version-specific differences across supported iOS releases.

### Scroll indicator

1. Scroll view delegate/event path.
2. Actual indicator visibility lifecycle.
3. Fade or removal timing.
4. Cancellation/restart behavior during continuous scrolling.

## Acceptance criteria

- The scroll indicator must genuinely leave the visible state after the configured delay rather than only receiving a cosmetic alpha change.
- Layout must react to orientation, device class, and safe-area changes.
- Private hooks must be version-gated when symbols or behavior differ.
- No filesystem state is introduced unless it is required and its path uses the project's RootHide-safe resolver abstraction.

## Evidence required before implementation

For each hook, document the target process, class/selector, iOS versions, call-path role, and fallback behavior.
