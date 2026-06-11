extends CanvasLayer
## F3 debug overlay: the sim's X-ray. You cannot balance a 200-NPC town by
## walking around in real time — this table is how the simulation is tested.

var _refresh_accum := 0.0

@onready var panel: PanelContainer = $Panel
@onready var text: RichTextLabel = %DebugText


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_accum += delta
	if _refresh_accum < 0.5:
		return
	_refresh_accum = 0.0
	_refresh()


func _refresh() -> void:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]  |  speed %sx  |  player @ %s" % [
		GameClock.time_string(),
		"0" if GameClock.paused else str(GameClock.time_scale),
		Locations.display_name(WorldState.player_location_id)])

	var by_location: Dictionary = {}
	var by_activity: Dictionary = {}
	var embodied := 0
	var traveling := 0
	for npc in WorldState.npcs.values():
		var loc: String = "traveling" if npc.traveling else npc.current_location_id
		by_location[loc] = by_location.get(loc, 0) + 1
		by_activity[npc.current_activity] = by_activity.get(npc.current_activity, 0) + 1
		if npc.agent != null:
			embodied += 1
		if npc.traveling:
			traveling += 1
	lines.append("NPCs: %d total | %d embodied | %d traveling" % [
		WorldState.npcs.size(), embodied, traveling])

	lines.append("\n[b]By location:[/b]")
	var locs := by_location.keys()
	locs.sort()
	for loc in locs:
		lines.append("  %s: %d" % [Locations.display_name(loc), by_location[loc]])

	lines.append("\n[b]By activity:[/b]")
	var acts := by_activity.keys()
	acts.sort()
	for act in acts:
		lines.append("  %s: %d" % [act, by_activity[act]])

	# Nearest few NPCs in detail (the spot-check view).
	if WorldState.player_location_id != "exterior":
		lines.append("\n[b]Here with you:[/b]")
		var here := 0
		for npc in WorldState.npcs.values():
			if npc.current_location_id == WorldState.player_location_id and here < 8:
				here += 1
				lines.append("  %s (%s) — %s" % [npc.display_name,
						npc.archetype().display_name if npc.archetype() else "?",
						npc.current_activity])

	text.text = "\n".join(lines)
