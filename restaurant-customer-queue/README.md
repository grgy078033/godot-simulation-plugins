# Restaurant Customer Queue System

Small, focused simulation systems for building a living world in Godot.

Restaurant Customer Queue System is a lightweight typed Godot addon for strict FIFO restaurant arrivals, smallest-suitable table assignment and explicit customer lifecycle state. The manager reports assignment through the customer Resources; it does not create a restaurant simulation around your game.

## Features

- Inspector-friendly `RestaurantCustomer` and `RestaurantTable` Resources
- `CustomerQueue` with strict FIFO order and no priority or patience subsystem
- `RestaurantQueueManager` Node for registration, head-of-line seating and completion
- Smallest suitable table selection with registration-order ties
- Two-way customer/table ownership invariant without a Resource cycle
- Caller-controlled `waiting_time` and service lifecycle states
- Exact `state_changed(old_state, new_state)` signals only for actual changes
- No autoload, timer, menu, money, movement, navigation, save system or third-party dependency
- Full typed GDScript source and an external-controls native demo

## Installation

1. Extract the ZIP and import its `project.godot` in Godot 4.7.2. Press F5 to run the included demo.
2. For an existing project, copy only `addons/restaurant_customer_queue/` into its `addons/` folder.
3. Add a plain Node with `RestaurantQueueManager` attached, create `RestaurantCustomer` and `RestaurantTable` Resources, then register them with `add_customer()` and `add_table()`.

No plugin activation is required. The optional `plugin.cfg` is packaging metadata; enabling it adds no editor UI. The addon is independent of the demo and does not require an autoload or another collection product.

## Quick start

Create editable Resources in the Inspector or build them in code. Connect each customer's signal before registration so the initial `ARRIVING -> QUEUING -> SEATED` or `WAITING_FOR_TABLE` transitions are observable:

```gdscript
extends Node

var manager: RestaurantQueueManager
var customer: RestaurantCustomer
var table: RestaurantTable

func _ready() -> void:
    manager = RestaurantQueueManager.new()
    add_child(manager)

    customer = RestaurantCustomer.new()
    customer.customer_id = &"alice"
    customer.party_size = 2
    customer.state_changed.connect(_on_customer_state_changed)

    table = RestaurantTable.new()
    table.table_id = &"table_2"
    table.capacity = 2

    manager.add_table(table) # Also tries to seat the current queue head.
    manager.add_customer(customer) # Alice becomes SEATED immediately.
    print(customer.assigned_table.table_id) # table_2

func _on_customer_state_changed(old_state: int, new_state: int) -> void:
    print("Customer state: ", old_state, " -> ", new_state)
```

`add_customer()` treats a valid non-completed Resource as an arrival, changes it to `QUEUING`, and then immediately tries assignment. `add_table()` also immediately retries the queue. A successful arrival becomes `SEATED`; when the queue head has no suitable available table it becomes `WAITING_FOR_TABLE`.

The manager does not advance service. After seating, your own game can call `set_state()` for `ORDERING`, `WAITING_FOR_FOOD`, `EATING`, `PAYING` and `LEAVING`, then call `complete_customer()` when the party is finished:

```gdscript
func advance_service(customer: RestaurantCustomer) -> void:
    customer.set_state(RestaurantCustomer.CustomerState.ORDERING)
    customer.set_state(RestaurantCustomer.CustomerState.WAITING_FOR_FOOD)
    customer.set_state(RestaurantCustomer.CustomerState.EATING)
    customer.set_state(RestaurantCustomer.CustomerState.PAYING)
    customer.set_state(RestaurantCustomer.CustomerState.LEAVING)
    manager.complete_customer(customer) # Releases only its own table and seats the next head.
```

## Public API

### `RestaurantCustomer extends Resource`

`RestaurantCustomer` is an Inspector-friendly party Resource. Its `assigned_table` link and live-manager claim are runtime-only and are not exported or serialized.

| Member | Type | Meaning |
| --- | --- | --- |
| `CustomerState` | enum | `ARRIVING`, `QUEUING`, `WAITING_FOR_TABLE`, `SEATED`, `ORDERING`, `WAITING_FOR_FOOD`, `EATING`, `PAYING`, `LEAVING`, `COMPLETED`. |
| `customer_id` | `StringName` | Caller-defined identity. Empty IDs are allowed; nonempty IDs must be unique within one manager. |
| `party_size` | `int` | Positive party size required for registration and seating. |
| `state` | `int` | Inspector-visible state property. Assignment uses `set_state()` and emits only on a real valid change; manager completion makes that runtime instance terminal. |
| `assigned_table` | `RestaurantTable` or `null` | Runtime forward ownership link. The manager/table updates it consistently. |
| `waiting_time` | `float` | Caller-owned bookkeeping value. The addon never increments, clamps or interprets it. |
| `set_state(new_state)` | `void` | Set an explicit lifecycle state; equal values are suppressed. |
| `get_state()` | `int` | Read the current enum value. |
| `state_changed(old_state, new_state)` | signal | Exact integer enum values, emitted only when the stored state changes. |

Every public customer API can be used directly:

```gdscript
var guest := RestaurantCustomer.new()
guest.customer_id = &"bob"
guest.party_size = 4
guest.waiting_time = 2.5

guest.state_changed.connect(func(old_state: int, new_state: int) -> void:
    print("state signal: ", old_state, " -> ", new_state)
)
print(guest.get_state() == RestaurantCustomer.CustomerState.ARRIVING) # true
guest.set_state(RestaurantCustomer.CustomerState.QUEUING)
guest.state = RestaurantCustomer.CustomerState.WAITING_FOR_TABLE # property uses the same signal path
print(guest.get_state())
```

### `RestaurantTable extends Resource`

A table Resource keeps a weak reverse link to its assigned customer and a separate weak claim from its live queue manager. The customer keeps the strong forward link. This avoids a `Resource` reference cycle while keeping `table.assigned_customer` and `customer.assigned_table` consistent during normal assignment; neither runtime link is serialized.

| Member or method | Type | Meaning |
| --- | --- | --- |
| `table_id` | `StringName` | Caller-defined identity. Empty IDs are allowed; nonempty IDs must be unique within one manager. |
| `capacity` | `int` | Positive maximum party size. Nonpositive tables are rejected by the manager. |
| `occupied` | `bool` | Read-only runtime query derived from the weak assignment. |
| `assigned_customer` | `RestaurantCustomer` or `null` | Read-only runtime property backed by a weak reverse reference. Use `assign_customer()` and `release()` to mutate ownership. |
| `can_seat(party_size)` | `bool` | Checks positive party size, capacity and current occupancy. |
| `assign_customer(customer)` | `bool` | Assigns one unassigned compatible customer and updates both links. |
| `release()` | `RestaurantCustomer` or `null` | Clears both links and returns the released customer. It does not change customer state. |

Direct table use is small and deterministic:

```gdscript
var table := RestaurantTable.new()
table.table_id = &"patio_2"
table.capacity = 2
var guest := RestaurantCustomer.new()
guest.customer_id = &"carol"
guest.party_size = 1

if table.can_seat(guest.party_size) and table.assign_customer(guest):
    print(table.occupied, " / ", table.assigned_customer.customer_id)
    print(guest.assigned_table == table) # true
var released: RestaurantCustomer = table.release()
print(released == guest, " / ", table.occupied) # true / false
```

`release()` is a low-level ownership operation. If your manager owns the table, use `complete_customer()` so the queue is retried immediately. If external code releases a manager-owned table, call `try_assign_tables()` afterward.

### `CustomerQueue extends RefCounted`

`CustomerQueue` is a strict FIFO value container. It rejects `null`, nonpositive parties, duplicate instances and duplicate nonempty IDs. It never sorts by party size, waiting time or state.

| Method | Return | Meaning |
| --- | --- | --- |
| `enqueue(customer)` | `bool` | Append a valid unique customer. |
| `dequeue()` | `RestaurantCustomer` or `null` | Remove and return the oldest customer. |
| `remove_customer(customer)` | `bool` | Remove that exact queued instance. |
| `get_next_customer()` | `RestaurantCustomer` or `null` | Peek at the head without removing it. |
| `get_queue_size()` | `int` | Number of queued customers. |

The queue can be used without a Node:

```gdscript
var queue := CustomerQueue.new()
var alice := RestaurantCustomer.new()
alice.customer_id = &"alice"
alice.party_size = 2
var bob := RestaurantCustomer.new()
bob.customer_id = &"bob"
bob.party_size = 4

queue.enqueue(alice)
queue.enqueue(bob)
print(queue.get_next_customer() == alice) # true
print(queue.get_queue_size()) # 2
print(queue.dequeue() == alice) # true
queue.remove_customer(bob)
print(queue.dequeue() == null) # true
```

### `RestaurantQueueManager extends Node`

The manager is one local runtime registration. It does not create a global registry or service container and has no required signals of its own; listen to each `RestaurantCustomer.state_changed` signal.

| Method | Return | Meaning |
| --- | --- | --- |
| `add_customer(customer)` | `bool` | Rejects `null`, nonpositive parties, duplicate instances/IDs, Resources owned by another live manager, assigned customers and terminal/`COMPLETED` customers; otherwise registers an arrival and retries seating. |
| `add_table(table)` | `bool` | Rejects `null`, nonpositive capacity, duplicate instances/IDs, Resources owned by another live manager and already occupied tables; otherwise registers the table and retries seating. |
| `try_assign_tables()` | `void` | Reconciles the queue head repeatedly while suitable tables exist. Safe to call after external table release. |
| `complete_customer(customer)` | `bool` | Completes one registered non-completed customer, releases only its own manager table, and immediately retries the next queue head. |
| `get_waiting_customers()` | `Array[RestaurantCustomer]` | Fresh FIFO snapshot of queued customers; changing the returned array does not mutate the manager. |
| `get_available_tables()` | `Array[RestaurantTable]` | Fresh registration-order snapshot of valid unoccupied tables. |

A manager example using the included editable `.tres` Resources looks like this. Resources are duplicated for this runtime instance; the `$` node path is not used to fetch a Resource:

```gdscript
extends Node

const ALICE_CONFIG: RestaurantCustomer = preload("res://demo/alice.tres")
const TABLE_TWO_CONFIG: RestaurantTable = preload("res://demo/table_two.tres")

var manager: RestaurantQueueManager
var alice: RestaurantCustomer
var table_two: RestaurantTable

func _ready() -> void:
    manager = RestaurantQueueManager.new()
    add_child(manager)
    alice = ALICE_CONFIG.duplicate(true) as RestaurantCustomer
    table_two = TABLE_TWO_CONFIG.duplicate(true) as RestaurantTable
    alice.state_changed.connect(_on_alice_state_changed)
    manager.add_table(table_two)
    manager.add_customer(alice)
    var waiting: Array[RestaurantCustomer] = manager.get_waiting_customers()
    var available: Array[RestaurantTable] = manager.get_available_tables()
    print("waiting=", waiting.size(), " available=", available.size())
    manager.try_assign_tables()

func _on_alice_state_changed(old_state: int, new_state: int) -> void:
    if new_state == RestaurantCustomer.CustomerState.SEATED:
        print("Alice seated at ", alice.assigned_table.table_id)
```

The manager chooses the smallest suitable available capacity. If capacities tie, the first registered table wins. FIFO is strict: a larger queue head blocks later parties even when a later party would fit. A party of four never skips a queue head merely because a two-seat table is free. Each live manager claims its registered customer/table Resources through a weak, nonserialized owner link; a second manager rejects the same Resource even before seating. This is per-Resource ownership, not a global registry. Freeing the manager clears that weak claim; active table links remain caller-visible until released.

Successful registration routes `ARRIVING -> QUEUING -> SEATED` when seating succeeds, or `ARRIVING -> QUEUING -> WAITING_FOR_TABLE` when it cannot. Completion changes the customer to `COMPLETED`, marks that runtime instance terminal, drops the manager's strong registration and releases its weak manager claim. The same instance cannot be registered or completed again, even if a caller later tries to change its state. A new Resource instance may use the same ID after the old party has been released; this addon keeps no history registry. The manager does not force `ORDERING`, `WAITING_FOR_FOOD`, `EATING`, `PAYING` or `LEAVING` transitions.

Both links are established or cleared before the corresponding customer state signal is emitted. A minimal mutation guard rejects manager mutations attempted re-entrantly from a state callback while the current assignment/completion is settling. Inspect the invariant in a callback, then request another manager mutation on the next caller turn if needed. Direct `RestaurantTable.assign_customer()` and `release()`, and standalone `CustomerQueue`, remain low-level operations and do not claim a manager; use manager methods when a table belongs to a queue manager.

## Resource ownership and serialization

The `.tres` files in `demo/` are editable configuration values. Manager registration is runtime ownership: it mutates the customer's state and uses runtime assignment links. If two gameplay instances need independent state, deep-duplicate their configuration Resources before registration:

```gdscript
var runtime_customer: RestaurantCustomer = preload("res://demo/alice.tres").duplicate(true) as RestaurantCustomer
var runtime_table: RestaurantTable = preload("res://demo/table_two.tres").duplicate(true) as RestaurantTable
manager.add_table(runtime_table)
manager.add_customer(runtime_customer)
```

The runtime forward/reverse links and weak manager claims are intentionally not exported, so saving a customer or table Resource does not serialize an ownership cycle or manager reference. Save your own queue/assignment decisions if your game needs persistence; this addon has no save system. A completed runtime instance is terminal; duplicate the original configuration Resource before creating a fresh party.

## Demo

Run `demo/demo.tscn` or press F5. The demo duplicates three editable customer Resources and two editable table Resources for its runtime. Tables register in reverse capacity order so Alice's two-person party visibly chooses the smallest suitable table. Add Alice, Bob and Carol; Carol waits in FIFO order. The lifecycle button advances seated customers through the caller-owned service states. Completing a table sets its customer to `COMPLETED`, releases that table and immediately attempts to seat the next queued party.

The UI is an example only: it contains no menu, order, money, movement, patience timer or restaurant simulation. Edit `demo/alice.tres`, `demo/bob.tres`, `demo/carol.tres`, `demo/table_two.tres` and `demo/table_four.tres` to change Inspector values.

## Scope boundaries

This asset intentionally does **not** include a menu, order system, money, payment processing, patience/timer subsystem, inventory, food, cooking, NPC AI, movement, navigation, calendar, save/load, database, networking, cutscenes or a UI framework. It is a complementary independent logic API, not a built-in Godot integration.

## Compatibility

Tested with **Godot 4.7.2 stable** on Windows using the Compatibility renderer. Headless core checks and native rendered UI checks are included in the release validation. Other Godot versions and operating systems are not certified by this release. No C#, GDExtension, third-party dependency or plugin activation is required.

## License

Free and open source under the [MIT License](LICENSE.txt), starting with v1.0.1. You may use, modify, redistribute and use this addon in commercial or closed-source games; retain the MIT copyright and permission notice. No payment or Star is required.

[Source, issues and contributions on GitHub](https://github.com/grgy078033/godot-simulation-plugins). If this helps your game, consider giving the project a Star. itch.io downloads are free; donations are optional. Earlier purchased copies retain their original terms; anyone can obtain this MIT release.

## More Godot Simulation Tools

Looking for more lightweight systems?

- [NPC Routine Scheduler](https://grgy078033.itch.io/npc-routine-scheduler) — Resolve daily NPC locations and activities from your own game clock.
- [Food Freshness & Expiration System](https://grgy078033.itch.io/food-freshness) — Calculate fresh, stale and expired states from item age in game days.
- [World Event Scheduler](https://grgy078033.itch.io/world-event-scheduler) — Resolve daily world events and start/end signals, including overnight windows.
- [NPC Relationship & Gifting System](https://grgy078033.itch.io/npc-relationship-gifting) — Give NPCs relationship points, gift preferences and configurable levels.

Compatible with other plugins in the Godot Simulation Systems collection. No plugin is required to use another. These are complementary independent logic APIs, not built-in integrations.
