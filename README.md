# Focus Capsule

Focus Capsule is a native macOS floating context island for quick work capture,
timeline review, and jump-back actions.

## Run

```sh
swift run FocusCapsule
```

The app runs as a menu bar utility and opens a floating capsule panel. Use the
menu bar item to expand/collapse, refresh context, install CLI hooks, or quit.

Drag the capsule near the top edge to dock it as a compact island. Drag it near
the left or right edge to collapse it into a shelf. Tap a docked capsule to
expand it again.

## Build the App

```sh
scripts/build-app.sh
```

The packaged app is created at:

```text
.build/release/Focus Capsule.app
```

## Permissions

Focus Capsule works in metadata-only mode without permissions. For richer window
and browser context, allow:

- Accessibility
- Automation
- Screen Recording

## CLI Hooks

The `Install CLI Hooks` action installs an independent `focuscapsule` bridge for
Claude, Codex, and Cursor. It appends its own hook entries and does not overwrite
CodeIsland entries.

## Verify

```sh
swift build
swift run FocusCapsuleCoreSmokeTests
```
