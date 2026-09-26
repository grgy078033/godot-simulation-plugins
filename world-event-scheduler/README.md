# World Event Scheduler

Small, focused simulation systems for building a living world in Godot.

World Event Scheduler is a lightweight typed Godot addon for repeating daily event windows. Define when a shop, light system, music cue or other world label is active; pass your own clock to a Node; respond to `event_started` and `event_ended`. The addon reports state and signals only. It does not create spawners, weather, a calendar or an event bus.

## Features

- Inspector-friendly `ScheduledEvent` and `EventSchedule` Resources
- Half-open `[start, end)` windows, including overnight windows
- Concurrent events with deterministic first-valid duplicate-ID handling
- Strictly-next start lookup and minutes-until-start queries
- `WorldEventScheduler` Node with destination-state reconciliation
- Ended signals before started signals, with safe deferred callback re-entry
- No autoload, timer, per-frame processing, calendar, save system or third-party dependency
- Full typed GDScript source and a native external-clock demo

## Installation

1. Extract the ZIP and import its `project.godot` in Godot 4.7.2. Press F5 to run the demo.
2. For an existing project, copy only `addons/world_event_scheduler/` into its `addons/` folder.
3. Add a plain Node with `WorldEventScheduler` attached, assign an `EventSchedule` Resource, and forward your own clock.

No plugin activation is required. The optional `plugin.cfg` is packaging metadata; enabling it adds no editor UI. The addon is independent of the included demo and does not require an autoload or another collection product.

## Quick start

Create Resources in the Inspector or in code, then forward the current time from your existing clock:

```gdscript
extends Node

@onready var scheduler: WorldEventScheduler = $WorldEventScheduler

func _ready() -> void:
    scheduler.event_started.connect(_on_event_started)
    scheduler.event_ended.connect(_on_event_ended)
    scheduler.update_time(19, 0) # Your clock owns the time.

func _on_event_started(event_id: StringName) -> void:
    print("Started: ", event_id)

func _on_event_ended(event_id: StringName) -> void:
    print("Ended: ", event_id)
```

A minimal schedule can be built in code:

```gdscript
var shop := ScheduledEvent.new()
shop.event_id = &"shop_open"
shop.start_hour = 8
shop.end_hour = 18

var lights := ScheduledEvent.new()
lights.event_id = &"street_lights"
lights.start_hour = 18
lights.end_hour = 6 # Overnight: active from 18:00 through 05:59.

var schedule := EventSchedule.new()
schedule.events.assign([shop, lights])
scheduler.schedule = schedule
scheduler.update_time(22, 0)
print(scheduler.get_active_event_ids()) # ["street_lights"]
```

The caller owns the clock and decides when to call `update_time()`. Calling it before `_ready()` is safe. The Node does not process time in `_process()`, start a timer, or replay every skipped hour.

## Public API

### `ScheduledEvent extends Resource`

| Member | Type | Meaning |
| --- | --- | --- |
| `event_id` | `StringName` | Caller-defined identity. Empty IDs are invalid. |
| `start_hour` / `end_hour` | `int` | Resource clock hour, valid from `0` through `23`. |
| `start_minute` / `end_minute` | `int` | Resource clock minute, valid from `0` through `59`. |

An event uses the half-open interval `[start, end)`: it is active at its start and inactive exactly at its end. If start is later than end, the interval crosses midnight. Equal start and end means zero duration and is inactive, not all-day. Invalid clock fields or empty IDs make an entry invalid for all queries.

### `EventSchedule extends Resource`

| Member or method | Type | Meaning |
| --- | --- | --- |
| `events` | `Array[ScheduledEvent]` | Inspector-editable event list. Query results never reorder it. |
| `is_event_active(event_id, hour, minute)` | `bool` | Tests the first valid event with that ID at a normalized clock time. |
| `get_active_events(hour, minute)` | `Array[ScheduledEvent]` | Returns a new array of active, first-valid events in inspector order. |
| `get_next_event(hour, minute)` | `ScheduledEvent` or `null` | Returns the next valid nonzero-duration start strictly after the normalized time. |
| `minutes_until_event(event_id, hour, minute)` | `int` | Minutes to that event's next start; `1440` at exact start, `-1` for unknown/invalid/zero-duration IDs. |

A nullable-safe query block can use each schedule method directly:

```gdscript
var hour: int = 19
var minute: int = 0
if schedule.is_event_active(&"street_lights", hour, minute):
    print("Lights are active")
var active: Array[ScheduledEvent] = schedule.get_active_events(hour, minute)
for event: ScheduledEvent in active:
    print(event.event_id)
var next_event: ScheduledEvent = schedule.get_next_event(hour, minute)
if next_event != null:
    var minutes: int = schedule.minutes_until_event(next_event.event_id, hour, minute)
    print(next_event.event_id, " starts in ", minutes, " minutes")
```

Query hours and minutes are normalized modulo 1440, so values outside `0..23` and `0..59` are accepted from the caller. Upcoming starts wrap to the next day; an exact start is therefore 1440 minutes away. If several starts have the same next distance, input order wins. Active queries can return multiple distinct IDs at once.

Null slots and invalid entries are ignored. For duplicate nonempty IDs, the first valid entry wins; later duplicates do not become a fallback. A zero-duration entry is a valid resource window for identity purposes but is inactive and excluded from upcoming starts.

### `WorldEventScheduler extends Node`

| Member or method | Type | Meaning |
| --- | --- | --- |
| `schedule` | `EventSchedule` or `null` | Assigned schedule Resource. Replacing it is observed on the next `update_time()`. |
| `update_time(hour, minute)` | `void` | Normalizes the clock and reconciles the destination active-ID set. |
| `get_active_event_ids()` | `Array[StringName]` | Fresh read-only snapshot of IDs active after the latest update. |
| `event_started(event_id)` | signal | Emitted for each newly active destination ID. |
| `event_ended(event_id)` | signal | Emitted for each ID absent from the destination set. |

The first update emits `event_started` for every active event. Repeating a time in the same active window emits nothing. Jumps and rewinds reconcile only the destination state: skipped intermediate starts are not replayed. On each update, ended IDs are emitted before newly started IDs, and the cached destination state is published before either signal callback runs. A null or replaced schedule ends previously active IDs once on its next update.

Signal callbacks may call `update_time()` safely. While a signal batch is being emitted, the latest requested time is deferred until that batch completes; it is then reconciled normally. This is a small mutation guard, not an event bus.

## Demo

Run `demo/demo.tscn` or press F5. The editable `demo/event_schedule.tres` shows:

- Shop Open: `08:00–18:00`
- Street Lights: `18:00–06:00`
- Tavern Music: `20:00–23:00`
- Ghost Spawn: `22:00–05:00`

The demo starts at 19:00, provides `−1 hour` and `+1 hour` controls, displays active IDs and the next start, and records transition signals. The labels are illustrative only; no shop, light, music, weather or spawner logic is included.

## Scope boundaries

This is a complementary independent logic API, not a built-in Godot integration. It intentionally does **not** include a calendar or clock, event bus, world spawner, NPC AI, weather, lighting controller, audio system, navigation, movement, networking, save/load, database, custom editor, UI framework or required autoload. Your project remains responsible for time, gameplay actions and persistence.

## Compatibility

Tested with **Godot 4.7.2 stable** on Windows using the Compatibility renderer. Other Godot versions and operating systems are not certified by this release. No C#, GDExtension, third-party runtime dependency or plugin activation is required.

## License

Free and open source under the [MIT License](LICENSE.txt), starting with v1.0.1. You may use, modify, redistribute and use this addon in commercial or closed-source games; retain the MIT copyright and permission notice. No payment or Star is required.

[Source, issues and contributions on GitHub](https://github.com/grgy078033/godot-simulation-plugins). If this helps your game, consider giving the project a Star. itch.io downloads are free; donations are optional. Earlier purchased copies retain their original terms; anyone can obtain this MIT release.

## More Godot Simulation Tools

Looking for more lightweight systems?

- [NPC Routine Scheduler](https://grgy078033.itch.io/npc-routine-scheduler) — Resolve daily NPC locations and activities from your own game clock.
- [Restaurant Customer Queue System](https://grgy078033.itch.io/restaurant-customer-queue) — Manage FIFO customer queues, suitable tables and caller-controlled customer states.
- [Food Freshness & Expiration System](https://grgy078033.itch.io/food-freshness) — Calculate fresh, stale and expired states from item age in game days.
- [NPC Relationship & Gifting System](https://grgy078033.itch.io/npc-relationship-gifting) — Give NPCs relationship points, gift preferences and configurable levels.

Compatible with other plugins in the Godot Simulation Systems collection. No plugin is required to use another. These are complementary independent logic APIs, not built-in integrations.
