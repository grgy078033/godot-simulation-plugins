extends SceneTree
## Dependency-free core contract runner:
## godot --headless --path . --script tests/test_core.gd

var _checks: int = 0
var _failures: int = 0
var _relationship_events: Array[Vector2i] = []
var _gift_items: Array[StringName] = []
var _gift_reactions: Array[int] = []
var _gift_deltas: Array[int] = []
var _reentrant_component: RelationshipComponent = null


func _initialize() -> void:
	var profile := _profile()
	var component := RelationshipComponent.new()
	component.profile = profile
	component.relationship_changed.connect(_on_relationship_changed)
	component.gift_given.connect(_on_gift_given)
	_check(component.get_points() == 0, "profile starts at zero")
	_check(component.points == 0, "points property mirrors getter")
	_check(is_equal_approx(component.get_normalized_relationship(), 0.0), "normalized zero")
	_check(component.get_relationship_level().level_id == &"stranger", "zero selects Stranger")

	component.set_points(100)
	_check(component.get_points() == 100, "set points")
	_check(component.get_normalized_relationship() == 0.1, "normalized tenth")
	_check(component.get_relationship_level().level_id == &"stranger", "100 remains Stranger")
	var coffee_result: GiftResult = component.give_gift(&"coffee")
	_check(coffee_result.reaction == GiftPreference.Reaction.LOVE, "coffee LOVE reaction")
	_check(coffee_result.base_points == 50, "coffee base points")
	_check(coffee_result.final_points == 50, "coffee applied points")
	_check(component.get_points() == 150, "100 plus coffee equals 150")
	_check(_relationship_events.size() == 2, "set and coffee relationship signals")
	_check(_relationship_events[0] == Vector2i(0, 100), "set relationship signal args")
	_check(_relationship_events[1] == Vector2i(100, 150), "coffee relationship signal args")
	_check(_gift_items == [&"coffee"], "coffee gift item signal")
	_check(_gift_reactions == [GiftPreference.Reaction.LOVE], "coffee gift reaction signal")
	_check(_gift_deltas == [50], "coffee gift applied delta signal")

	var birthday_result: GiftResult = component.give_gift(&"coffee", 2.0)
	_check(birthday_result.base_points == 50 and birthday_result.final_points == 100, "coffee birthday doubles to 100")
	_check(component.get_points() == 250, "birthday points")
	_check(_gift_items.size() == 2 and _gift_deltas[1] == 100, "birthday gift signal")
	var cake_result: GiftResult = component.give_gift(&"cake", 0.5)
	_check(cake_result.reaction == GiftPreference.Reaction.LIKE, "cake LIKE reaction")
	_check(cake_result.base_points == 20 and cake_result.final_points == 10, "cake rounds scaled points")
	var trash_result: GiftResult = component.give_gift(&"trash", 0.5)
	_check(trash_result.reaction == GiftPreference.Reaction.HATE, "trash HATE reaction")
	_check(trash_result.base_points == -40 and trash_result.final_points == -20, "negative gift scales")
	_check(component.get_points() == 240, "cake and trash applied")

	var unknown_result: GiftResult = component.give_gift(&"unknown")
	_check(unknown_result.reaction == GiftPreference.Reaction.NEUTRAL, "unknown is neutral")
	_check(unknown_result.base_points == 0 and unknown_result.final_points == 0, "unknown changes no points")
	_check(component.get_points() == 240, "unknown preserves points")
	_check(_gift_items.size() == 5 and _gift_items[4] == &"unknown", "neutral gift still signals")
	_check(_gift_deltas[4] == 0, "neutral gift signal delta is zero")

	var relationship_count: int = _relationship_events.size()
	component.set_points(component.get_points())
	component.points = component.get_points()
	_check(_relationship_events.size() == relationship_count, "unchanged points suppress relationship signal")
	var clamped_result: GiftResult = component.give_gift(&"coffee", 100.0)
	_check(clamped_result.base_points == 50 and clamped_result.final_points == 760, "gift result reports actual upper clamp delta")
	_check(component.get_points() == 1000, "maximum clamp")
	_check(_gift_items.size() == 6 and _gift_deltas[5] == 760, "clamped gift still signals actual delta")
	var zero_result: GiftResult = component.give_gift(&"coffee", 0.0)
	_check(zero_result.final_points == 0 and component.get_points() == 1000, "zero multiplier is valid and no-op")
	_check(_gift_items.size() == 7 and _gift_deltas[6] == 0, "zero multiplier gift signal")
	var gift_count_before_invalid: int = _gift_items.size()
	var nan_result: GiftResult = component.give_gift(&"coffee", NAN)
	_check(nan_result.base_points == 50 and nan_result.final_points == 0, "NaN multiplier safely gives no points")
	_check(_gift_items.size() == gift_count_before_invalid, "invalid NaN multiplier is not a valid gift attempt")
	var infinity_result: GiftResult = component.give_gift(&"coffee", INF)
	_check(infinity_result.final_points == 0 and _gift_items.size() == gift_count_before_invalid, "infinite multiplier is rejected")
	var negative_multiplier_result: GiftResult = component.give_gift(&"coffee", -1.0)
	_check(negative_multiplier_result.final_points == 0 and _gift_items.size() == gift_count_before_invalid, "negative multiplier is rejected")
	component.set_points(100)
	var huge_multiplier_result: GiftResult = component.give_gift(&"coffee", 1.0e308)
	_check(huge_multiplier_result.final_points == 0 and component.get_points() == 100, "nonfinite scaled gift safely rejects without sign reversal")
	_check(_gift_items.size() == gift_count_before_invalid, "nonfinite scaled gift emits no signal")
	var oversized_finite_result: GiftResult = component.give_gift(&"coffee", 1.0e18)
	_check(oversized_finite_result.final_points == 900 and component.get_points() == 1000, "finite oversized gift safely saturates at maximum")

	var reentrant_component := RelationshipComponent.new()
	reentrant_component.profile = profile
	reentrant_component.set_points(100)
	_reentrant_component = reentrant_component
	_gift_deltas.clear()
	reentrant_component.relationship_changed.connect(_on_reentrant_relationship_changed)
	reentrant_component.gift_given.connect(_on_gift_given)
	var reentrant_result: GiftResult = reentrant_component.give_gift(&"coffee")
	_check(reentrant_result.final_points == 50, "gift result captures delta before signal reentry")
	_check(reentrant_component.get_points() == 0, "relationship callback mutation still runs")
	_check(_gift_deltas == [50], "gift signal reports captured delta after callback mutation")
	_reentrant_component = null
	reentrant_component.free()

	component.set_points(-50)
	_check(component.get_points() == 0, "set points clamps at minimum")
	component.add_points(-25)
	_check(component.get_points() == 0, "negative add clamps at minimum")
	component.add_points(25)
	component.remove_points(10)
	_check(component.get_points() == 15, "signed add/remove arithmetic")
	component.remove_points(-5)
	_check(component.get_points() == 20, "negative remove adds points by policy")
	component.add_points(2000)
	_check(component.get_points() == 1000, "add clamps at maximum")

	var levels_profile := RelationshipProfile.new()
	levels_profile.minimum_points = 0
	levels_profile.maximum_points = 1000
	var duplicate_acquaintance := _level(200, &"duplicate", "Duplicate threshold")
	var friend := _level(400, &"friend", "Friend")
	var stranger := _level(0, &"stranger_first", "First zero threshold")
	levels_profile.levels.assign([null, friend, duplicate_acquaintance, stranger, _level(200, &"duplicate_later", "Later duplicate")])
	var levels_component := RelationshipComponent.new()
	levels_component.profile = levels_profile
	levels_component.set_points(399)
	_check(levels_component.get_relationship_level() == duplicate_acquaintance, "unsorted levels choose highest eligible threshold")
	levels_component.set_points(400)
	_check(levels_component.get_relationship_level() == friend, "400 selects Friend")
	levels_component.set_points(200)
	_check(levels_component.get_relationship_level() == duplicate_acquaintance, "duplicate level threshold keeps first")
	levels_component.set_points(0)
	_check(levels_component.get_relationship_level() == stranger, "first eligible zero threshold")
	levels_component.set_points(1001)
	_check(levels_component.get_points() == 1000, "level test component maximum clamp")
	levels_component.free()

	var duplicate_profile := RelationshipProfile.new()
	var first_coffee := _preference(&"coffee", GiftPreference.Reaction.LIKE, 3)
	var later_coffee := _preference(&"coffee", GiftPreference.Reaction.HATE, -999)
	duplicate_profile.gift_preferences.assign([null, first_coffee, later_coffee])
	var duplicate_component := RelationshipComponent.new()
	duplicate_component.profile = duplicate_profile
	var duplicate_result: GiftResult = duplicate_component.give_gift(&"coffee")
	_check(duplicate_result.reaction == GiftPreference.Reaction.LIKE and duplicate_result.base_points == 3, "duplicate item keeps first non-null preference")
	duplicate_component.free()

	var zero_width_profile := RelationshipProfile.new()
	zero_width_profile.minimum_points = 200
	zero_width_profile.maximum_points = 100
	var zero_width_component := RelationshipComponent.new()
	zero_width_component.profile = zero_width_profile
	zero_width_component.set_points(0)
	_check(zero_width_component.get_points() == 200, "misconfigured bounds use effective maximum minimum")
	_check(zero_width_component.get_normalized_relationship() == 0.0, "zero-width normalized relationship is zero")
	_check(zero_width_component.get_relationship_level() == null, "no levels returns null")
	zero_width_component.free()

	var missing_profile_component := RelationshipComponent.new()
	_check(missing_profile_component.get_points() == 0, "missing profile starts at zero")
	missing_profile_component.set_points(40)
	_check(missing_profile_component.get_points() == 0, "missing profile has zero baseline")
	_check(missing_profile_component.get_normalized_relationship() == 0.0, "missing profile normalized zero")
	_check(missing_profile_component.get_relationship_level() == null, "missing profile level null")
	var missing_result: GiftResult = missing_profile_component.give_gift(&"coffee")
	_check(missing_result.reaction == GiftPreference.Reaction.NEUTRAL and missing_result.final_points == 0, "missing profile gift safe neutral")
	missing_profile_component.free()

	var isolation_profile := _profile()
	var first_component := RelationshipComponent.new()
	var second_component := RelationshipComponent.new()
	first_component.profile = isolation_profile
	second_component.profile = isolation_profile
	first_component.set_points(100)
	second_component.set_points(700)
	first_component.give_gift(&"coffee")
	_check(first_component.get_points() == 150 and second_component.get_points() == 700, "shared profile state remains isolated")
	first_component.free()
	second_component.free()

	var replacement_component := RelationshipComponent.new()
	replacement_component.profile = profile
	replacement_component.relationship_changed.connect(_on_relationship_changed)
	replacement_component.set_points(900)
	_relationship_events.clear()
	var narrower_profile := RelationshipProfile.new()
	narrower_profile.minimum_points = 100
	narrower_profile.maximum_points = 200
	replacement_component.profile = narrower_profile
	_check(replacement_component.get_points() == 200, "profile replacement preserves then clamps points")
	_check(_relationship_events.size() == 1 and _relationship_events[0] == Vector2i(900, 200), "profile replacement emits actual clamp")
	replacement_component.free()

	var save_profile := _profile()
	var save_path: String = "user://relationship_profile_test.tres"
	var save_error: Error = ResourceSaver.save(save_profile, save_path)
	_check(save_error == OK, "profile resource saves")
	var loaded_profile: RelationshipProfile = load(save_path) as RelationshipProfile
	_check(loaded_profile != null, "profile resource loads")
	if loaded_profile != null:
		_check(loaded_profile.npc_id == &"alice", "serialized profile npc id")
		_check(loaded_profile.gift_preferences.size() == 3, "serialized preference array")
		_check(loaded_profile.levels.size() == 5, "serialized level array")
		_check(loaded_profile.gift_preferences[0].item_id == &"coffee", "serialized first preference")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	component.free()

	print("CORE: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _profile() -> RelationshipProfile:
	var profile := RelationshipProfile.new()
	profile.npc_id = &"alice"
	profile.minimum_points = 0
	profile.maximum_points = 1000
	profile.gift_preferences.assign([
		_preference(&"coffee", GiftPreference.Reaction.LOVE, 50),
		_preference(&"cake", GiftPreference.Reaction.LIKE, 20),
		_preference(&"trash", GiftPreference.Reaction.HATE, -40),
	])
	profile.levels.assign([
		_level(800, &"best_friend", "Best Friend"),
		_level(0, &"stranger", "Stranger"),
		_level(600, &"close_friend", "Close Friend"),
		_level(200, &"acquaintance", "Acquaintance"),
		_level(400, &"friend", "Friend"),
	])
	return profile


func _preference(item_id: StringName, reaction: int, relationship_change: int) -> GiftPreference:
	var preference := GiftPreference.new()
	preference.item_id = item_id
	preference.reaction = reaction
	preference.relationship_change = relationship_change
	return preference


func _level(minimum_points: int, level_id: StringName, display_name: String) -> RelationshipLevel:
	var level := RelationshipLevel.new()
	level.minimum_points = minimum_points
	level.level_id = level_id
	level.display_name = display_name
	return level


func _on_relationship_changed(old_value: int, new_value: int) -> void:
	_relationship_events.append(Vector2i(old_value, new_value))


func _on_gift_given(item_id: StringName, reaction: int, relationship_change: int) -> void:
	_gift_items.append(item_id)
	_gift_reactions.append(reaction)
	_gift_deltas.append(relationship_change)


func _on_reentrant_relationship_changed(_old_value: int, _new_value: int) -> void:
	if _reentrant_component != null:
		_reentrant_component.set_points(0)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
