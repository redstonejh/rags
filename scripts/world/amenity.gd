class_name Amenity
extends Interactable
## Time-consuming need stations: beds, showers, TVs, benches.
## kind drives behavior; quality scales the payoff.

@export var kind: String = "shower" # shower | tv | bed | bench
@export var quality: float = 1.0

const AMENITY_TEXTURES := {
	"bed": "res://assets/props/bed.png",
	"shower": "res://assets/props/shower.png",
	"tv": "res://assets/props/tv.png",
	"bench": "res://assets/props/bench.png",
}


func _init() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 30)
	shape.shape = rect
	add_child(shape)


func configure(p_kind: String, p_quality: float, p_name: String, p_verb: String, color: Color) -> void:
	kind = p_kind
	quality = p_quality
	display_name = p_name
	verb = p_verb
	if _add_prop_sprite():
		return
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-13, -10), Vector2(13, -10), Vector2(13, 12), Vector2(-13, 12)])
	visual.color = color
	add_child(visual)


func _add_prop_sprite() -> bool:
	if not AMENITY_TEXTURES.has(kind):
		return false
	var texture: Texture2D = load(AMENITY_TEXTURES[kind])
	if texture == null:
		return false
	var sprite := Sprite2D.new()
	sprite.name = "PropSprite"
	sprite.texture = texture
	sprite.texture_filter = 1
	sprite.position = Vector2(0, -4)
	add_child(sprite)
	return true


func interact(actor: Node) -> void:
	if not ("needs" in actor and actor.needs is Needs):
		return
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null:
		return
	match kind:
		"shower":
			var before := sheet.needs.get_value("hygiene")
			GameClock.skip_minutes(20)
			sheet.needs.change("hygiene", 70.0 * quality)
			var gain := int(round(sheet.needs.get_value("hygiene") - before))
			EventBus.survival_feedback.emit("shower", "Clean Up",
					"20 minutes. Hygiene %+d." % gain)
			EventBus.toast.emit("Cleaned up. Hygiene +%d." % gain)
		"tv":
			var before := sheet.needs.get_value("fun")
			GameClock.skip_minutes(45)
			sheet.needs.change("fun", 30.0 * quality)
			var gain := int(round(sheet.needs.get_value("fun") - before))
			EventBus.survival_feedback.emit("fun", "Kill Time",
					"45 minutes. Fun %+d." % gain)
			EventBus.toast.emit("Killed 45 minutes. Fun +%d." % gain)
		"bed":
			if sheet.housing_id == "":
				EventBus.toast.emit("You don't live here. The bed knows.")
				return
			_sleep(sheet, 12.0 * quality)
		"bench":
			_sleep(sheet, 6.0 * quality)
			sheet.needs.change("hygiene", -15.0)
	EventBus.player_interacted.emit(self)


## Sleep until 7 AM (or at least 1 hour if it's already morning).
func _sleep(sheet: CharacterSheet, restore_per_hour: float) -> void:
	var now := GameClock.total_minutes
	var to_seven := (7 * 60 - (now % GameClock.MINUTES_PER_DAY) + GameClock.MINUTES_PER_DAY) % GameClock.MINUTES_PER_DAY
	if to_seven < 60:
		to_seven = 60
	var hours := to_seven / 60.0
	var energy_before := sheet.needs.get_value("energy")
	GameClock.skip_minutes(to_seven)
	sheet.needs.change("energy", restore_per_hour * hours)
	var energy_gain := sheet.needs.get_value("energy") - energy_before
	EventBus.survival_feedback.emit("sleep", "Sleep",
			"%.1f hour%s until 7 AM. Energy %+d." % [
				hours,
				"" if is_equal_approx(hours, 1.0) else "s",
				int(round(energy_gain))])
	EventBus.toast.emit("Slept %.1f hour%s. Energy +%d. It is, regrettably, tomorrow." % [
			hours, "" if is_equal_approx(hours, 1.0) else "s", int(round(energy_gain))])
