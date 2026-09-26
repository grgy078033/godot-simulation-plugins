# NPC Routine Scheduler for Godot 4

Lightweight daily NPC schedules without requiring a full calendar framework.

## Overview

Give a scheduler your game time; get the NPC's current location, activity and next routine. Each entry lasts until the next start time. The last entry continues across midnight. No clock, movement or calendar is created for you.

## Features

- Lightweight: linear scans of small schedules, no per-frame processing
- Full typed GDScript source
- No external dependencies, autoloads or native extensions
- Works with any time/calendar system that supplies hour and minute
- Daily NPC routines and overnight schedule support
- Current routine lookup and next routine lookup
- Time-until-next-event calculation
- Schedule change signals
- Inspector-friendly Resources, with unsorted entries supported

## Installation

1. Extract the ZIP. To try the demo, import its `project.godot` in Godot and press F6 with `demo/demo.tscn` open, or F5.
2. To integrate, copy only `addons/npc_routine_scheduler/` into your project's `addons/` folder.
3. Wait for Godot to scan the scripts. `ScheduleEntry`, `NPCSchedule` and `NPCScheduler` become available as global classes.

**No plugin activation is required.** The optional `plugin.cfg` is packaging metadata; enabling it adds no editor UI. The addon works without copying the demo or its assets.

## Quick Start

1. Add an `NPCScheduler` node to your NPC scene using Create Node (or attach `npc_scheduler.gd` to a plain Node).
2. In its **Schedule** property, choose **New NPCSchedule**.
3. Expand **Entries**, set its size, and choose **New ScheduleEntry** for each element.
4. Set each entry's Hour, Minute, Location ID and Activity.
5. Forward your clock changes, including the initial time after connecting signals:

```gdscript
extends Node

@onready var scheduler: NPCScheduler = $NPCScheduler

func _ready() -> void:
    scheduler.schedule_changed.connect(_on_schedule_changed)
    scheduler.update_time(8, 0) # Replace with your clock's current time.

func _on_time_changed(hour: int, minute: int) -> void:
    scheduler.update_time(hour, minute)

func _on_schedule_changed(entry: ScheduleEntry) -> void:
    if entry == null:
        return # No valid schedule: clear your NPC state if appropriate.
    print(entry.location_id)
    print(entry.activity)
```

## Creating a Schedule

Example daily schedule:

| Time | Location ID | Activity |
| --- | --- | --- |
| 07:00 | Home | Breakfast |
| 08:00 | Restaurant | Working |
| 17:00 | Park | Walking |
| 20:00 | Tavern | Relaxing |
| 23:00 | Home | Sleeping |

At 15:00 this resolves to Restaurant / Working; at 02:00 it resolves to the previous day's 23:00 Home / Sleeping entry.

Resources can also be created in the FileSystem dock via **New Resource**, saved as `.tres`, and assigned to multiple schedulers. See `demo/alice.tres`, `bob.tres` and `carol.tres`. IDs are arbitrary `StringName` values: the addon does not look up scene nodes or move NPCs.

## Connecting Your Time System

The addon does not declare or require a `TimeManager`. If your existing manager emits exactly two integer arguments `(hour, minute)`, connect it directly:

```gdscript
# In your own project, where TimeManager is already defined:
# TimeManager.time_changed.connect(scheduler.update_time)
```

Alternatively, adapt your clock's signal in `_on_time_changed` as shown above. After connecting, call `update_time` once using the clock's current time. Loading an NPC halfway through the day needs no simulated catch-up.

Forward time jumps, rewinds and minute changes using the same API. Large jumps resolve the destination entry only; skipped entries do not emit events.

## Listening for Schedule Changes

`schedule_changed(entry: ScheduleEntry)` fires when `update_time` resolves a **different Resource instance**. The new `current_entry` is already stored when listeners run.

- The first valid update emits once. Repeated updates in the same entry do not emit.
- Two different entries with identical location/activity still count as a change.
- Moving from a valid entry to an absent/empty schedule emits `null` once.
- Starting with no schedule emits nothing (`null` to `null`).
- Editing fields of the same entry is not a new entry and does not emit a change.

Connect before the initial `update_time`; check for `null` in your listener. Do not treat this as a timer that re-fires every day for a single-entry schedule.

## Getting the Next Routine

```gdscript
func show_next(hour: int, minute: int) -> void:
    scheduler.update_time(hour, minute)
    var current: ScheduleEntry = scheduler.get_current_entry()
    var next: ScheduleEntry = scheduler.get_next_entry()
    if current != null:
        print("Now: ", current.location_id, " / ", current.activity)
    if next != null:
        print("Next: %s at %02d:%02d" % [next.location_id, next.hour, next.minute])
    if scheduler.schedule != null:
        var remaining: int = scheduler.schedule.minutes_until_next_entry(hour, minute)
        print("Minutes remaining: ", remaining) # -1 means no valid entries.
```

Next means **strictly after now**, wrapping to tomorrow if necessary. At a start time, that entry is current, not next (unless it is the only distinct start time, in which case next is tomorrow).

## Example

All Resource APIs can be used without a Node:

```gdscript
func example() -> void:
    var work := ScheduleEntry.new()
    work.hour = 8
    work.minute = 0
    work.location_id = &"Restaurant"
    work.activity = &"Working"
    print(work.get_total_minutes()) # 480

    var park := ScheduleEntry.new()
    park.hour = 17
    park.location_id = &"Park"
    park.activity = &"Walking"

    var routine := NPCSchedule.new()
    routine.entries.assign([park, work]) # Sorting is not required.
    var current: ScheduleEntry = routine.get_entry_at(15, 30)
    var next: ScheduleEntry = routine.get_next_entry(15, 30)
    print(current.location_id) # Restaurant
    print(next.location_id) # Park
    print(routine.minutes_until_next_entry(15, 30)) # 90
```

### Public API reference

| Type | Member | Contract |
| --- | --- | --- |
| ScheduleEntry | `hour: int`, `minute: int` | Inspector ranges 0–23 and 0–59 |
| ScheduleEntry | `location_id: StringName`, `activity: StringName` | User-defined identifiers |
| ScheduleEntry | `get_total_minutes() -> int` | Raw `hour * 60 + minute` |
| NPCSchedule | `entries: Array[ScheduleEntry]` | Editable list; never reordered by queries |
| NPCSchedule | `get_entry_at(hour: int, minute: int) -> ScheduleEntry` | Latest start at/before now, otherwise previous day's last; nullable |
| NPCSchedule | `get_next_entry(hour: int, minute: int) -> ScheduleEntry` | Next strictly future start, otherwise tomorrow's first; nullable |
| NPCSchedule | `minutes_until_next_entry(hour: int, minute: int) -> int` | 1–1440, or -1 if there are no valid entries |
| NPCScheduler | `schedule: NPCSchedule` | Assigned Resource, nullable |
| NPCScheduler | `current_entry: ScheduleEntry` | Cached result; treat as read-only |
| NPCScheduler | `update_time(hour: int, minute: int) -> void` | Store time, resolve entry, emit only on identity change |
| NPCScheduler | `get_current_entry() -> ScheduleEntry` | Cached current; null before first update |
| NPCScheduler | `get_next_entry() -> ScheduleEntry` | Query using last supplied time; null before first update |
| NPCScheduler | `schedule_changed(entry: ScheduleEntry)` | Nullable entry; see signal rules above |

### Edge cases and mutation

- A day is exactly 1440 minutes. Query time is normalized modulo a day: `(24, 0)` is midnight and `(0, -1)` is 23:59. Supply ordinary game-sized integers.
- Empty schedules and lists containing only invalid entries return `null` / `-1`.
- Null slots and entries with hours outside 0–23 or minutes outside 0–59 are ignored. Inspector ranges guide editing but cannot prevent invalid values assigned from code.
- Duplicate start times: **first valid entry in array order wins**, consistently for current and next. Prefer unique start times.
- Single entry: current is always that entry; next is its next occurrence. At its exact start time the wait is **1440**, not zero.
- Each query is O(n), does not mutate the array, and returns the original Resource, not a copy. There is no cache to invalidate in `NPCSchedule`.
- After assigning/replacing a schedule or changing entries at runtime, call `update_time` again before reading the scheduler's current state. The scheduler does not monitor Resource edits automatically. `get_next_entry` queries the assigned schedule live using the last time.
- Shared Resources share edits. Duplicate a Resource (including subresources) if individual NPCs require independent editable schedules.

## Demo

Run `demo/demo.tscn`. Alice, Bob and Carol show current location, activity, next entry and minutes remaining. Use **-1 Hour** / **+1 Hour**; time wraps across midnight in both directions. Edit the three `.tres` files to change routines.

The demo is intentionally a status display, not NPC movement, navigation, needs or life-simulation AI. It uses native Controls and no external art/fonts. Recommended viewport: 1100 × 700 or larger.

## Compatibility

Tested with **Godot 4.7.2 stable**, GDScript, on Windows, using the Compatibility renderer. Headless core/integration tests and native rendered UI checks were performed. Other Godot 4 versions and operating systems are not certified by this release. No C#, GDExtension, third-party time framework or plugin activation is required.

## License

Free and open source under the [MIT License](LICENSE.txt), starting with v1.0.1. You may use, modify, redistribute and use this addon in commercial or closed-source games; retain the MIT copyright and permission notice. No payment or Star is required.

[Source, issues and contributions on GitHub](https://github.com/grgy078033/godot-simulation-plugins). If this helps your game, consider giving the project a Star. itch.io downloads are free; donations are optional. Earlier purchased copies retain their original terms; anyone can obtain this MIT release.

## More Godot Simulation Tools

Looking for more lightweight systems?

- [NPC Relationship & Gifting System](https://grgy078033.itch.io/npc-relationship-gifting) — Give NPCs relationship points, gift preferences and configurable levels.
- [World Event Scheduler](https://grgy078033.itch.io/world-event-scheduler) — Resolve daily world events and start/end signals, including overnight windows.
- [Food Freshness & Expiration System](https://grgy078033.itch.io/food-freshness) — Calculate fresh, stale and expired states from item age in game days.
- [Restaurant Customer Queue System](https://grgy078033.itch.io/restaurant-customer-queue) — Manage FIFO customer queues, suitable tables and caller-controlled customer states.

Compatible with other plugins in the Godot Simulation Systems collection. No plugin is required to use another. These are complementary independent logic APIs, not built-in integrations.
