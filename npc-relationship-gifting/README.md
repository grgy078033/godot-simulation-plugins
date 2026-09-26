# NPC Relationship & Gifting System

A small, typed Godot Resource + Node addon for relationship points, gift reactions and named levels. Give a component your profile and point state; call `give_gift()` when your own game logic decides that a gift was offered. The addon does not create an inventory, calendar, dialogue system or NPC AI.

## Features

- `RelationshipProfile` Resources with editable bounds, gift preferences and levels
- `RelationshipComponent` Node with clamped points and two focused signals
- Love, like, neutral, dislike and hate reactions with configured point changes
- Caller-supplied multipliers for cases such as birthdays
- Unsorted Inspector arrays, null-slot tolerance and deterministic duplicate handling
- No autoload, required plugin activation, third-party dependency, timer or save system
- Full typed GDScript source and an external-controls demo

## Installation

1. Extract the ZIP and import its `project.godot` in Godot 4.7.2. Press F6 with `demo/demo.tscn` open, or press F5.
2. For an existing project, copy only `addons/npc_relationship_gifting/` into its `addons/` folder.
3. Add a `RelationshipComponent` to a scene and assign a `RelationshipProfile` in the Inspector. No plugin activation is required. The optional `plugin.cfg` is packaging metadata; enabling it adds no editor UI.

The addon is independent: it does not require the demo, an inventory, a calendar, another addon or an autoload.

## Quick start

Create a profile in code or as a `.tres` Resource, then assign it to a plain Node with the component script:

```gdscript
extends Node

@onready var relationship: RelationshipComponent = $RelationshipComponent

func _ready() -> void:
    relationship.relationship_changed.connect(_on_relationship_changed)
    relationship.gift_given.connect(_on_gift_given)
    relationship.set_points(100)
    # The caller supplies any context-specific multiplier.
    var result: GiftResult = relationship.give_gift(&"coffee", 2.0)
    print(result.reaction, " applied ", result.final_points, " points")

func _on_relationship_changed(old_value: int, new_value: int) -> void:
    print("Relationship: ", old_value, " -> ", new_value)

func _on_gift_given(item_id: StringName, reaction: int, relationship_change: int) -> void:
    print("Gift ", item_id, ": ", reaction, " / ", relationship_change)
```

`set_points()`, `add_points()`, `remove_points()` and `give_gift()` are safe before `_ready()`. Assigning or replacing `profile` preserves the component's existing points and clamps them only if the new bounds require it; entering the tree never resets an already assigned point value. A profile replacement that changes the stored value emits `relationship_changed` with the actual old and new values. A profile Resource is shared by reference: separate components keep independent point state but see edits to shared preferences and levels. If you edit a shared profile's bounds in place, the component does not monitor the Resource; explicitly refresh with `relationship.set_points(relationship.get_points())` when you want the new bounds applied.

The other point and query APIs are ordinary callable methods:

```gdscript
relationship.add_points(25) # signed; clamp to the profile bounds
relationship.remove_points(10)
print(relationship.get_points())
print(relationship.get_normalized_relationship()) # [0.0, 1.0]
var level: RelationshipLevel = relationship.get_relationship_level()
if level != null:
    print(level.level_id, " / ", level.display_name)
```

A `.tres` profile can be edited in the Inspector:

```gdscript
var profile := RelationshipProfile.new()
profile.npc_id = &"alice"
profile.minimum_points = 0
profile.maximum_points = 1000

var coffee := GiftPreference.new()
coffee.item_id = &"coffee"
coffee.reaction = GiftPreference.Reaction.LOVE
coffee.relationship_change = 50
profile.gift_preferences.append(coffee)

var friend := RelationshipLevel.new()
friend.minimum_points = 400
friend.level_id = &"friend"
friend.display_name = "Friend"
profile.levels.append(friend)
```

## Behavior and edge cases

- Stored points are clamped to `minimum_points` through an effective maximum of `max(maximum_points, minimum_points)`. A missing profile uses a zero/neutral baseline: points remain `0`, normalization is `0.0`, levels are `null`, and gifts are neutral with zero change.
- `get_normalized_relationship()` returns a value in `[0.0, 1.0]`. A zero-width or misconfigured range returns `0.0`.
- `add_points(amount)` adds a signed amount and `remove_points(amount)` subtracts a signed amount. Thus `add_points(-10)` removes ten and `remove_points(-10)` adds ten; both still clamp to the profile bounds. `set_points()` also clamps.
- Preferences are scanned in array order. Null slots are ignored and the first matching duplicate `item_id` wins. An unknown item is `NEUTRAL` with base and applied points of zero.
- Levels do not need sorting. Null slots are ignored; the highest `minimum_points` less than or equal to the current points wins. If thresholds are duplicated, the first matching level wins. No match returns `null`.
- `give_gift(item_id, multiplier)` requires a finite, nonnegative multiplier. An invalid multiplier returns a zero-applied `GiftResult` and emits no `gift_given` signal. A valid zero multiplier is still a gift attempt and emits. Scaled points are rounded to the nearest integer. Nonfinite scaled multiplication is rejected safely; a finite scaled value beyond the safe integer-conversion range saturates toward the corresponding effective bound instead of overflowing. `GiftResult.base_points` is the configured unscaled change; `GiftResult.final_points` and the signal's `relationship_change` are the actual applied delta after clamping.
- Every valid gift attempt emits `gift_given`, including unknown, neutral, zero and fully clamped gifts. `relationship_changed` emits only when stored points differ.
- There is no inventory removal. Birthday or other context multiplication is supplied by your caller; no calendar integration or birthday framework is included.

## Public API

### `GiftPreference extends Resource`

| Member | Type | Meaning |
| --- | --- | --- |
| `item_id` | `StringName` | Caller-defined gift identity. |
| `reaction` | `GiftPreference.Reaction` | `LOVE`, `LIKE`, `NEUTRAL`, `DISLIKE` or `HATE`. |
| `relationship_change` | `int` | Unscaled point delta, positive or negative. |

### `RelationshipLevel extends Resource`

| Member | Type | Meaning |
| --- | --- | --- |
| `minimum_points` | `int` | Inclusive threshold. |
| `level_id` | `StringName` | Caller-defined stable ID. |
| `display_name` | `String` | Text suitable for UI. |

### `RelationshipProfile extends Resource`

| Member | Type | Meaning |
| --- | --- | --- |
| `npc_id` | `StringName` | Caller-defined profile identity. |
| `minimum_points` | `int` | Inclusive lower bound. |
| `maximum_points` | `int` | Upper bound before effective-bound normalization. |
| `gift_preferences` | `Array[GiftPreference]` | Editable preference list; order resolves duplicates. |
| `levels` | `Array[RelationshipLevel]` | Editable threshold list; order resolves duplicate thresholds. |

### `GiftResult extends RefCounted`

| Member | Type | Meaning |
| --- | --- | --- |
| `reaction` | `int` | The resolved `GiftPreference.Reaction` value. |
| `base_points` | `int` | Configured, unscaled preference change. |
| `final_points` | `int` | Actual stored-point delta after multiplier, rounding and clamping. |

### `RelationshipComponent extends Node`

| Member | Type | Meaning |
| --- | --- | --- |
| `profile` | `RelationshipProfile` | Assigned profile; nullable and Inspector-friendly. |
| `points` | `int` | Property mirror of the stored, clamped point state. |
| `add_points(amount)` | `void` | Add signed points and clamp. |
| `remove_points(amount)` | `void` | Subtract signed points and clamp. |
| `set_points(value)` | `void` | Replace points and clamp. |
| `get_points()` | `int` | Read stored points. |
| `get_normalized_relationship()` | `float` | Read normalized `[0, 1]` relationship. |
| `get_relationship_level()` | `RelationshipLevel` | Read the selected level, or `null`. |
| `give_gift(item_id, multiplier = 1.0)` | `GiftResult` | Resolve and apply a gift. |
| `relationship_changed(old_value, new_value)` | signal | Emitted only when stored points differ. |
| `gift_given(item_id, reaction, relationship_change)` | signal | Emitted for every valid gift attempt with the actual applied delta. |

## Demo

Run `demo/demo.tscn` to see Alice start at 320 points (`Acquaintance`) with bounds, normalization, the Coffee/Cake/Trash/Unknown profile entries, the last reaction and the applied delta. The birthday checkbox supplies multiplier `2.0` to the next gift. Alice reaches `Friend` at 400. The controls are external to the component; there is no inventory or calendar behind them. Edit `demo/alice_profile.tres` to change the Inspector resources.

## Scope boundaries

This asset intentionally does **not** include dialogue, dating, marriage, quests, NPC AI, inventory or item classes, save/load, cutscenes, calendars, birthday frameworks, movement, networking or a UI framework. It is a complementary independent API, not a built-in Godot integration.

## Compatibility

Tested with **Godot 4.7.2 stable** on Windows using the Compatibility renderer. Headless core checks and native rendered UI checks are included in the release validation. Other Godot versions and operating systems are not certified by this release. No C#, GDExtension, third-party dependency or plugin activation is required.

## License

Free and open source under the [MIT License](LICENSE.txt), starting with v1.0.1. You may use, modify, redistribute and use this addon in commercial or closed-source games; retain the MIT copyright and permission notice. No payment or Star is required.

[Source, issues and contributions on GitHub](https://github.com/grgy078033/godot-simulation-plugins). If this helps your game, consider giving the project a Star. itch.io downloads are free; donations are optional. Earlier purchased copies retain their original terms; anyone can obtain this MIT release.

## More Godot Simulation Tools

Looking for more lightweight systems?

- [NPC Routine Scheduler](https://grgy078033.itch.io/npc-routine-scheduler) — Resolve daily NPC locations and activities from your own game clock.
- [World Event Scheduler](https://grgy078033.itch.io/world-event-scheduler) — Resolve daily world events and start/end signals, including overnight windows.
- [Restaurant Customer Queue System](https://grgy078033.itch.io/restaurant-customer-queue) — Manage FIFO customer queues, suitable tables and caller-controlled customer states.
- [Food Freshness & Expiration System](https://grgy078033.itch.io/food-freshness) — Calculate fresh, stale and expired states from item age in game days.

Compatible with other plugins in the Godot Simulation Systems collection. No plugin is required to use another. These are complementary independent logic APIs, not built-in integrations.
