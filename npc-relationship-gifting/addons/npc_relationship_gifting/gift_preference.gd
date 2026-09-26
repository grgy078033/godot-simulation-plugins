@tool
class_name GiftPreference
extends Resource
## One item's reaction and its unscaled relationship-point change.

enum Reaction {
	LOVE,
	LIKE,
	NEUTRAL,
	DISLIKE,
	HATE,
}

@export var item_id: StringName = &""
@export var reaction: Reaction = Reaction.NEUTRAL
@export var relationship_change: int = 0
