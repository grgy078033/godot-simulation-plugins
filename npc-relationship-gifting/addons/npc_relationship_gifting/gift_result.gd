class_name GiftResult
extends RefCounted
## Value returned by RelationshipComponent.give_gift().
## final_points is the actual applied delta after clamping, not the configured value.

var reaction: int = GiftPreference.Reaction.NEUTRAL
var base_points: int = 0
var final_points: int = 0


func _init(gift_reaction: int = GiftPreference.Reaction.NEUTRAL, configured_points: int = 0, applied_points: int = 0) -> void:
	reaction = gift_reaction
	base_points = configured_points
	final_points = applied_points
