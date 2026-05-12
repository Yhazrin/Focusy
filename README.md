# Focusy

Focusy is a native macOS floating context island for quick work capture,
timeline review, and jump-back actions. It monitors active applications,
tracks context switches, and provides intelligent process detection.

## Run

```sh
swift run Focusy
```

The app runs as a menu bar utility and opens a floating capsule panel. Use the
menu bar item to expand/collapse, refresh context, install CLI hooks, or quit.

Drag the capsule near the top edge to dock it as a compact island. Drag it near
the left or right edge to collapse it into a shelf. Tap a docked capsule to
expand it again.

## Features

- **Process Detection**: Automatically detects and categorizes running applications
- **Context Switch Tracking**: Records application switches with duration
- **Idle Detection**: Tracks user idle time
- **Resource Monitoring**: CPU and memory usage for active apps
- **Smart Classification**: Groups apps into Communication, Development, Productivity, etc.

## Build the App

```sh
scripts/build-app.sh
```

The packaged app is created at:

```text
.build/release/Focusy.app
```

## Permissions

Focusy works in metadata-only mode without permissions. For richer window
and browser context, allow:

- Accessibility
- Automation
- Screen Recording

## CLI Hooks

The `Install CLI Hooks` action installs an independent `focusy` bridge for
Claude, Codex, and Cursor. It appends its own hook entries and does not overwrite
existing entries.

## Verify

```sh
swift build
swift run FocusyCoreSmokeTests
```
