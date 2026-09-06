# RecordingPillFix research plan

## Target

iOS 15–16 recording indicator elapsed-time behavior.

## Required execution-path trace

The implementation must establish the full path:

1. Recording begins.
2. The authoritative recording state is created or updated.
3. The authoritative start timestamp or elapsed-time source is stored.
4. The visible recording indicator is created.
5. The indicator is hidden and later shown again.
6. The elapsed-time label is refreshed after reappearance.
7. Recording stops and state is invalidated.

## Acceptance criteria

- No independent timer should replace a system timer unless the system has no reusable authoritative time source.
- Reappearing UI must calculate elapsed time from persistent recording state rather than the visual object's creation time.
- Hooks must be version-gated when iOS 15 and iOS 16 differ.
- No RootHide-specific physical path is hard-coded.
- The final package must contain only the intended payload.

## Evidence required before implementation

For every hooked class/selector, record:

- iOS version(s) observed
- framework/process containing the symbol
- caller/callee relationship
- role in recording state versus presentation state
- why it is the correct interception point
