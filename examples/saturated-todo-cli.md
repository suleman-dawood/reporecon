# 🔴 RepoRecon Report

> **Generated from fixture data** — this is an illustrative report, not a live RepoRecon run. Real reports require user-side validation (see README).

## Sharpened Idea

Sharpened idea: A command-line todo manager for developers, built in Rust

Preserved terms: ["Rust"]

Verdict: 🔴 "This exists"

## Run Metadata

- Timestamp: 2025-11-14T19:42:11Z
- gh rate budget (core) before run: 4998 / 5000
- gh rate budget (search) before run: 30 / 30
- gh rate budget (core) after run: 4961 / 5000
- gh rate budget (search) after run: 26 / 30

## Candidates

### example-dev/cli-todo-rust

[https://github.com/example-dev/cli-todo-rust](https://github.com/example-dev/cli-todo-rust) — verified at 2025-11-14T19:42:18Z

**Verdict:** LIKELY_MATCH

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 3 |
| target_audience | 3 |
| scope           | 2 |
| approach        | 3 |
| activity        | 2 |

Staleness: none

> README opens with "A fast, ergonomic todo manager for the terminal, written in Rust" — direct overlap on core_function, audience, and approach.

### rustacean-tools/rust-todoman

[https://github.com/rustacean-tools/rust-todoman](https://github.com/rustacean-tools/rust-todoman) — verified at 2025-11-14T19:42:19Z

**Verdict:** LIKELY_MATCH

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 3 |
| target_audience | 2 |
| scope           | 3 |
| approach        | 3 |
| activity        | 3 |

Staleness: none

> Description: "todoman, but rewritten in Rust for developers who live in the terminal" — same problem, same approach, actively maintained.

### crab-cli/taskcrab

[https://github.com/crab-cli/taskcrab](https://github.com/crab-cli/taskcrab) — verified at 2025-11-14T19:42:20Z

**Verdict:** LIKELY_MATCH

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 3 |
| target_audience | 2 |
| scope           | 2 |
| approach        | 3 |
| activity        | 2 |

Staleness: none

> README: "taskcrab is a CLI task manager in Rust with TUI mode" — covers core_function and approach, scoped slightly larger via TUI.

## Deep-Search Inspection

### example-dev/cli-todo-rust

[https://github.com/example-dev/cli-todo-rust](https://github.com/example-dev/cli-todo-rust) — verified at 2025-11-14T19:48:02Z — provenance: first

**Verdict:** EXACT_MATCH

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 3 |
| target_audience | 3 |
| scope           | 3 |
| approach        | 3 |
| activity        | 2 |

Staleness: none

**Evidence (file paths):**
- Cargo.toml:1-15
- src/main.rs:42
- src/commands/add.rs:18

> Cargo.toml declares it as a "terminal todo manager"; src/main.rs:42 shows the CLI dispatcher; identical problem and audience to the sharpened idea.

### rustacean-tools/rust-todoman

[https://github.com/rustacean-tools/rust-todoman](https://github.com/rustacean-tools/rust-todoman) — verified at 2025-11-14T19:48:14Z — provenance: first

**Verdict:** SIGNIFICANT_OVERLAP

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 3 |
| target_audience | 2 |
| scope           | 3 |
| approach        | 3 |
| activity        | 3 |

Staleness: none

**Evidence (file paths):**
- Cargo.toml:5
- src/lib.rs:88
- src/storage/sqlite.rs:120

> Same CLI todo workflow with SQLite storage backend (src/storage/sqlite.rs:120); audience is broader (also caldav users) so falls one step short of EXACT.

## Your Angle

The space is saturated for plain CLI todo managers in Rust — your wedge has to be a specific interaction model the incumbents do not implement.

**Features in your idea absent from all inspected candidates:**

- Natural-language input parsing (e.g., `todo "ship the report friday 3pm"`)
- Two-way calendar integration (CalDAV / Google Calendar sync, not just iCal export)
- Polished interactive TUI with mouse support and theming presets

## Deep-Search Inspection Stats

- Clones attempted: 2
- Clones succeeded: 2
- Clones skipped: 0 (oversize/timeout/LFS/injection)
- gh rate budget (core) deep-search delta: -12
- gh rate budget (search) deep-search delta: 0

## What's Next?

> Deep-search inspection complete. 2 candidates cloned; 0 skipped (oversize/timeout/LFS/injection). See **Your Angle** section above for differentiation guidance.
