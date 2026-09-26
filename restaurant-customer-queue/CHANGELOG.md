# Changelog

## 1.0.1 — Open-source release

- Released under MIT; free downloads with optional donations.
- Added the shared source repository, issue tracker and optional Star link.
- Corrected the optional no-op editor entry point to extend EditorPlugin.
- Customer/queue/table gameplay logic, demo scenes and Resources are unchanged from 1.0.0.

## 1.0.0 — 2026-02-17

- Added typed `RestaurantCustomer` and `RestaurantTable` Inspector Resources.
- Added strict FIFO `CustomerQueue` with deterministic identity rejection.
- Added `RestaurantQueueManager` table registration, smallest-fit seating and completion handoff.
- Added two-way runtime assignment with weak reverse table and manager ownership links plus exact customer state signals.
- Added terminal completion cleanup so completed party Resources are released without resurrection.
- Added editable Alice, Bob, Carol and table Resources with native external-controls demo.
- Added focused headless core and native demo validation scripts.
