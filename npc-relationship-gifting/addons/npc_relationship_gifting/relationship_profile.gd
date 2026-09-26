@tool
class_name RelationshipProfile
extends Resource
## Inspector-friendly relationship bounds, gift preferences and level thresholds.

@export var npc_id: StringName = &""
@export var minimum_points: int = 0
@export var maximum_points: int = 1000
@export var gift_preferences: Array[GiftPreference] = []
@export var levels: Array[RelationshipLevel] = []
