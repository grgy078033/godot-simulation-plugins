# How to give Godot NPCs a daily routine—without tying it to movement

[← Back to the collection](../README.md)

![Actual NPC Routine Scheduler status-panel demo](../media/npc-routine-scheduler-preview.gif)

**[Download the captioned 30-second demo (MP4)](https://raw.githubusercontent.com/grgy078033/godot-simulation-plugins/main/media/routine-daily-life-30s.mp4)** — silent, 1280×720. The footage shows schedule states, not built-in character movement.

An NPC does not need a complicated calendar to have a believable day. Start with a smaller question:

**Given the current game time, where should this NPC be, and what should they be doing?**

Here is Alice's example day:

| Start | Location | Activity |
|---|---|---|
| 07:00 | Home | Breakfast |
| 08:00 | Restaurant | Working |
| 17:00 | Park | Walking |
| 20:00 | Tavern | Relaxing |
| 23:00 | Home | Sleeping |

These are location and activity identifiers. They do not move a character by themselves.

## 1. Store transitions, not a separate rule for every minute

Each row starts a routine that remains active until the next row begins.

At 16:59, Alice is still working at the restaurant. At exactly 17:00, her intended location becomes the park and her activity becomes walking. There is no need to define a separate end time for the restaurant entry.

This also keeps schedule editing separate from behavior code: changing the work start time should not require editing a navigation script.

## 2. Treat midnight as a wrap, not an empty part of the day

Convert time into a minute-of-day value: hour × 60 + minute. Normalize query times into the 0–1439 range if your clock can pass out-of-range values.

To find the current routine:

1. Find the latest valid entry whose start time is less than or equal to the current time.
2. If none has started yet today, use the day's last valid entry.
3. If there are no valid entries, return no routine.

That second step matters. At 00:30, Alice should still be sleeping under the 23:00 entry—not have an undefined schedule until breakfast.

Keep a separate policy for bad data. For example, ignore invalid entry times and choose the first configured entry when two valid entries have the same start time. Document the rule so designers can predict the result.

## 3. Separate “current” from “next”

The next entry should mean a **strictly future** start.

At exactly 17:00, the park entry is current; the next entry is the tavern at 20:00, 180 minutes away. At 23:00, breakfast at 07:00 is next, 480 minutes away.

For a single-entry repeating schedule, its next occurrence at its exact start is tomorrow: 1,440 minutes away, not zero. These details are worth deciding before connecting a countdown label.

## 4. Keep three responsibilities separate

**Your clock → schedule lookup → your NPC behavior.**

- Your game decides how time advances, pauses or jumps.
- The schedule resolves a location/activity for that time.
- Your game maps the location identifier to a marker, pathfinding destination, scene or other behavior.

“Walking” is just an activity label until your game implements it. The same schedule logic can drive a status panel, off-screen simulation or a moving NPC.

When a clock jumps from 08:00 to 23:00, a state resolver should select the routine at the destination time. It is not automatically a replay of everything that happened between those times. Use a separate event system if your design needs every missed event to run.

## 5. Check the boundaries before polishing the UI

A useful small checklist:

- 16:59 → restaurant; 17:00 → park.
- 23:00 and 00:30 → home, sleeping.
- At 17:00, “next” means 20:00—not 17:00 again.
- An empty schedule is handled without dereferencing a missing entry.
- Jumping the clock selects the destination routine.
- Repeating the same resolved routine does not repeatedly trigger transition behavior.

## Using NPC Routine Scheduler

Disclosure: I maintain the free, MIT-licensed addon below. The schedule-design explanation above can also be used when implementing your own solution.

The free, open-source **NPC Routine Scheduler** implements this daily-routine approach with typed GDScript, Inspector-editable Resources, a small Node, and a runnable three-NPC demo.

A typical integration is:

1. Create an `NPCSchedule` Resource and add `ScheduleEntry` Resources in the Inspector.
2. Assign it to an `NPCScheduler` Node.
3. Connect `schedule_changed` before the first clock update.
4. Have your clock call `update_time(hour, minute)`.
5. In your own handler, handle a missing entry safely or use its `location_id` and `activity` to update your game's behavior.

These class and method names belong to the addon, not Godot's built-in API. It does not provide a clock, movement, pathfinding or a full calendar framework. Queries are intended for small daily schedules; this is not a claim about large-population performance.

The included Alice demo uses the timetable shown above. Tested with **Godot 4.7.2 on Windows, Compatibility renderer**; other versions and platforms are not certified.

**[Get the MIT source on GitHub](https://github.com/grgy078033/godot-simulation-plugins)** or [download free on itch.io](https://grgy078033.itch.io/npc-routine-scheduler), with optional donations.

The download includes full GDScript source, editable example Resources, a runnable demo, documentation and the MIT license. No other product, payment or Star is required. If the project helps you, a GitHub Star is appreciated.

[Browse all five standalone plugins](../README.md).
