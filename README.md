# iOS System UI Tweaks

A monorepo containing two independent jailbreak tweaks:

- **RecordingPillFix** — investigates and fixes the elapsed-time lifecycle of the iOS 15–16 recording indicator.
- **iOS26UI** — a separate SpringBoard UI project for Dock, Search, and scroll-indicator behavior inspired by newer iOS design patterns.

## Status

The repository is intentionally being initialized before private API hooks are written. The implementation process is:

1. Inspect the target repository and build environment.
2. Research the complete SpringBoard execution path for each feature.
3. Implement only verified hooks and selectors.
4. Keep the two packages independently buildable and distributable.
5. Validate produced packages, architecture, and RootHide path behavior.

## Layout

```text
RecordingPillFix/   # independent tweak package
  Docs/
  Source/

iOS26UI/            # independent tweak package
  Docs/
  Source/

scripts/            # package/binary verification
.github/workflows/   # CI after the build system is established
```

No undocumented class name or selector is treated as confirmed merely because it appears in an online header dump. Each implementation target must be traced and validated against the supported iOS versions.
