class_name FenceSpot
extends Interactable
## The fence, behind Site 9. Buys anything you're carrying at 40 cents on
## the dollar, no questions, paid in money that was never clean to begin
## with. Won't take the clothes off your back (literally — clothing and
## keys are excluded).

const RATE := 0.4
const EXCLUDED_TAGS := ["clothing", "key", "storage"]
const FENCE_SPOT_TEXTURE_PATH := "res://assets/props/fence_spot.png"


func _init() -> void:
	verb = "See"
	display_name = "the fence"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 34)
	shape.shape = rect
	add_child(shape)
	if not _add_prop_sprite():
		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([
			Vector2(-9, -13), Vector2(9, -13), Vector2(9, 13), Vector2(-9, 13)])
		visual.color = Color(0.3, 0.25, 0.32)
		add_child(visual)


func _add_prop_sprite() -> bool:
	var texture: Texture2D = load(FENCE_SPOT_TEXTURE_PATH)
	if texture == null:
		return false
	var sprite := Sprite2D.new()
	sprite.name = "PropSprite"
	sprite.texture = texture
	sprite.texture_filter = 1
	sprite.position = Vector2(0, -8)
	add_child(sprite)
	return true


func interact(_actor: Node) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	var total := 0
	var sold: Array = []
	for item_id in sheet.inventory.duplicate():
		var item := ContentDB.get_item(item_id)
		if item == null or item.value_cents <= 0:
			continue
		if item.tags.any(func(t: String) -> bool: return t in EXCLUDED_TAGS):
			continue
		total += int(item.value_cents * RATE)
		sold.append(item.display_name)
		sheet.inventory.erase(item_id)
	if sold.is_empty():
		EventBus.toast.emit("\"You're carrying nothing I want.\" He says it like a eulogy.")
		return
	sheet.dirty_cents += total
	sheet.add_skill_xp("streetwise", 1.0)
	EventBus.toast.emit("Fenced %d item%s for $%.2f. No receipts in this economy." % [
			sold.size(), "" if sold.size() == 1 else "s", total / 100.0])
