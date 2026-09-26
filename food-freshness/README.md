# Food Freshness & Expiration System

Small, focused simulation systems for building a living world in Godot.

Food Freshness & Expiration System is a lightweight typed Godot addon for day-based freshness state. Give each item a `FreshnessProfile` and a creation day; query its state or call `update_day()` when your own game clock advances. The addon reports state and signals only. It does not create inventory, food items, a clock or a save system.

## Features

- Inspector-friendly `FreshnessProfile` Resource with fresh and stale day durations
- Per-item `FreshnessInstance` RefCounted state with `FRESH`, `STALE` and `EXPIRED`
- Age and countdown queries that are safe before creation and at boundaries
- Silent pure lookups plus explicit `freshness_changed` and `expired` notifications
- Rewind-safe updates: a later expiry can notify again after a rewind
- Missing profiles and negative durations are handled safely
- No autoload, timer, per-frame processing, inventory, item framework or third-party dependency

## Installation

1. Extract the ZIP and import its `project.godot` in Godot 4.7.2. Press F5 to run the included demo.
2. For an existing project, copy only `addons/food_freshness/` into its `addons/` folder.
3. Create a `FreshnessProfile` Resource and create one `FreshnessInstance` for each item your own game owns. No plugin activation is required.

The optional `plugin.cfg` is packaging metadata; enabling it adds no editor UI. The addon is independent of the demo and does not require an autoload or another collection product.

## Quick start

Create a profile in code or assign `demo/freshness_profile.tres` in the Inspector. The caller owns the current day and chooses when to reconcile state:

```gdscript
extends Node

var profile: FreshnessProfile
var milk: FreshnessInstance

func _ready() -> void:
    profile = FreshnessProfile.new()
    profile.fresh_duration = 3
    profile.stale_duration = 2

    milk = FreshnessInstance.new()
    milk.setup(profile, 10) # Created on day 10; setup is silent.
    milk.freshness_changed.connect(_on_freshness_changed)
    milk.expired.connect(_on_expired)

    print(milk.get_state(12)) # FreshnessInstance.FreshnessState.FRESH
    print(milk.get_age(12)) # 2
    milk.update_day(13) # Emits FRESH -> STALE once.

func _on_freshness_changed(old_state: int, new_state: int) -> void:
    print("Freshness changed: ", old_state, " -> ", new_state)

func _on_expired() -> void:
    print("This item just entered EXPIRED.")
```

`FreshnessInstance` is a per-item `RefCounted`; it does not register itself globally. `setup(profile, created_day)` stores both values and silently initializes the comparison state at the creation day. Calling `setup()` again also resets that comparison state silently. A missing profile is safely `EXPIRED` with zero countdowns.

## Behavior and edge cases

- Age is `max(current_day - created_day, 0)`, so querying before creation safely returns age zero.
- Durations are normalized independently to `max(duration, 0)`. With fresh duration `3` and stale duration `2`, a food created on day `10` is fresh on days `10`, `11`, and `12`; stale on days `13` and `14`; and expired on day `15`.
- `FRESH` means `age < fresh_duration`; `STALE` means `age < fresh_duration + stale_duration`; otherwise the state is `EXPIRED`.
- `days_until_stale()` and `days_until_expired()` count down to the boundary and clamp at zero. They return zero for a missing profile.
- `get_state()`, `get_age()`, both countdowns and all `is_*()` predicates are pure lookups: they never mutate the cached comparison state or emit signals.
- `update_day(day)` compares the requested state with the previous update state. Repeated updates in the same state emit nothing. Rewinds emit reverse transitions, and a later transition into `EXPIRED` emits `expired()` again.
- `freshness_changed(old_state, new_state)` fires only when the state changes. `expired()` fires only when entering `EXPIRED`, not for setup, pure queries, repeated expired updates or a missing profile that remains expired.
- The profile Resource may be shared by multiple instances. The instances keep independent creation days and comparison states; profile edits are visible to later queries, but instances do not monitor Resource edits automatically.

## Public API

### `FreshnessProfile extends Resource`

| Member | Type | Meaning |
| --- | --- | --- |
| `fresh_duration` | `int` | Number of days in `FRESH` before normalization to zero or greater. Default `3`. |
| `stale_duration` | `int` | Number of days in `STALE` before normalization to zero or greater. Default `2`. |

An editable profile can also be created as a `.tres` Resource:

```gdscript
var profile: FreshnessProfile = load("res://data/food_profile.tres") as FreshnessProfile
profile.fresh_duration = 3
profile.stale_duration = 2
```

### `FreshnessInstance extends RefCounted`

| Member or method | Type | Meaning |
| --- | --- | --- |
| `FreshnessState` | enum | `FRESH`, `STALE`, `EXPIRED`. |
| `profile` | `FreshnessProfile` | Stored profile, nullable for the safe expired baseline. |
| `created_day` | `int` | Caller-supplied creation day. |
| `setup(profile, created_day)` | `void` | Stores the profile/day and silently initializes comparison state. |
| `get_state(current_day)` | `FreshnessState` | Pure state lookup using normalized durations. |
| `get_age(current_day)` | `int` | Nonnegative age. |
| `days_until_stale(current_day)` | `int` | Clamped days until the stale boundary. |
| `days_until_expired(current_day)` | `int` | Clamped days until the expired boundary. |
| `is_fresh(current_day)` | `bool` | True when the pure lookup is `FRESH`. |
| `is_stale(current_day)` | `bool` | True when the pure lookup is `STALE`. |
| `is_expired(current_day)` | `bool` | True when the pure lookup is `EXPIRED`. |
| `update_day(day)` | `void` | Reconciles and emits only actual state transitions. |
| `freshness_changed(old_state, new_state)` | signal | Exact old/new enum values for each state change. |
| `expired()` | signal | Emitted only when `update_day()` enters `EXPIRED`. |

Every method and signal can be used directly from a caller-owned clock:

```gdscript
func inspect_food(food: FreshnessInstance, day: int) -> void:
    var state: int = food.get_state(day)
    var age: int = food.get_age(day)
    var stale_in: int = food.days_until_stale(day)
    var expired_in: int = food.days_until_expired(day)
    if food.is_fresh(day):
        print("Fresh, age ", age, "; stale in ", stale_in)
    if food.is_stale(day):
        print("Stale, expired in ", expired_in)
    if food.is_expired(day):
        print("Expired at age ", age)
    print("State enum: ", state)
    food.update_day(day) # Notification path; pure methods above did not emit.
```

The caller can advance every instance from its own day system:

```gdscript
func _on_day_changed(day: int) -> void:
    for food: FreshnessInstance in foods:
        food.update_day(day)
```

## Demo

Run `demo/demo.tscn` or press F5. The native demo starts on day `10` and shows three independent instances using the editable `demo/freshness_profile.tres`:

- Milk created on day `8`: age `2`, `FRESH`, stale in `1` day and expired in `3` days.
- Fish created on day `5`: `EXPIRED`.
- Bread created on day `10`: age `0`, `FRESH`.

Use `− 1 day` and `+ 1 day` to drive `update_day()`. Each card displays created day, age, state, both countdowns and its last signal transition. The controls are external to the core API; there is no inventory or clock behind them.

## Scope boundaries

This asset intentionally does **not** include inventory, food/item classes, stacking, cooking, fridges, temperature, weather, calendars, clocks, save/load, timers, movement, networking, database, custom editor or UI framework. It is a complementary independent logic API, not a built-in Godot integration.

## Compatibility

Tested with **Godot 4.7.2 stable** on Windows using the Compatibility renderer. Headless core checks and native rendered UI checks are included in the release validation. Other Godot versions and operating systems are not certified by this release. No C#, GDExtension, third-party runtime dependency or plugin activation is required.

## License

Free and open source under the [MIT License](LICENSE.txt), starting with v1.0.1. You may use, modify, redistribute and use this addon in commercial or closed-source games; retain the MIT copyright and permission notice. No payment or Star is required.

[Source, issues and contributions on GitHub](https://github.com/grgy078033/godot-simulation-plugins). If this helps your game, consider giving the project a Star. itch.io downloads are free; donations are optional. Earlier purchased copies retain their original terms; anyone can obtain this MIT release.

## More Godot Simulation Tools

Looking for more lightweight systems?

- [Restaurant Customer Queue System](https://grgy078033.itch.io/restaurant-customer-queue) — Manage FIFO customer queues, suitable tables and caller-controlled customer states.
- [World Event Scheduler](https://grgy078033.itch.io/world-event-scheduler) — Resolve daily world events and start/end signals, including overnight windows.
- [NPC Routine Scheduler](https://grgy078033.itch.io/npc-routine-scheduler) — Resolve daily NPC locations and activities from your own game clock.
- [NPC Relationship & Gifting System](https://grgy078033.itch.io/npc-relationship-gifting) — Give NPCs relationship points, gift preferences and configurable levels.

Compatible with other plugins in the Godot Simulation Systems collection. No plugin is required to use another. These are complementary independent logic APIs, not built-in integrations.
