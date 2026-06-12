extends Node
## Exercises a real workplace interaction through Main, Player input,
## WorkSpot, ShiftSystem, and optional Dilemma UI.
## Run headless:
##   godot --headless --path <repo> res://scenes/dev/WorkShiftSmokeTest.tscn

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var failures := 0
var _main: Node = null
var _player: Node = null


func _ready() -> void:
	_setup_world()
	await _instantiate_main()
	await _test_diner_shift_interaction()
	print("Work shift smoke test: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _setup_world() -> void:
	var sheet := CharacterSheet.new()
	sheet.char_name = "Shift Walker"
	sheet.origin_id = "off_the_bus"
	sheet.cash_cents = 10000
	sheet.job_id = "dishwasher"
	sheet.flags["has_id"] = true
	WorldState.new_world(sheet)
	GameClock.total_minutes = GameClock.MINUTES_PER_DAY + 15 * 60 + 30
	GameClock.clear_pause_locks()
	GameClock.set_manual_paused(false)
	SaveManager.set_in_game(false)
	seed(7)


func _instantiate_main() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().physics_frame
	_player = _main.get_node("Player")
	_check(_player != null, "main scene has a player")


func _test_diner_shift_interaction() -> void:
	EventBus.travel_requested.emit("loc_diner")
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(WorldState.player_location_id == "loc_diner", "player enters diner for work")
	var work_spot := _find_descendant_of_type(_main.get("current_world"), WorkSpot) as WorkSpot
	_check(work_spot != null and work_spot.workplace_id == "loc_diner",
			"diner work spot exists")
	if work_spot == null:
		return

	var sheet := WorldState.player_sheet
	var job := ContentDB.get_job("dishwasher")
	var cash_before := sheet.cash_cents
	var day_before := GameClock.day
	_player.set("global_position", work_spot.global_position)
	await get_tree().physics_frame
	_player.call("_physics_process", 0.0)
	_player.call("_unhandled_input", _action("interact"))
	await get_tree().process_frame

	_check(_hud_has_toast("Clocking in: Dishwasher"),
			"work interaction shows a clock-in cue")
	_check(_hud_has_toast("6h 30m until 10:00 PM"),
			"clock-in cue reports the fast-forward duration")
	_check(_hud_has_toast("Clocked out."),
			"work interaction shows a paycheck cue")
	_check(_survival_feedback_kind() == "work",
			"work interaction shows the survival feedback vignette")
	_check(_survival_feedback_detail().contains("Expected pay: $54.00") \
			and _survival_feedback_detail().contains("10:00 PM"),
			"work vignette reports pay and clock-out")
	_check(GameClock.day == day_before and GameClock.hour == 22 and GameClock.minute == 0,
			"work interaction fast-forwards to shift end")
	_check(sheet.cash_cents == cash_before + job.wage_cents_per_shift,
			"work interaction pays the shift wage before any dilemma choice")
	_check(sheet.shifts_worked == 1, "shift count increments")
	_check(float(sheet.skills.get("cooking", 0.0)) >= job.skill_xp_per_shift,
			"work interaction trains the job skill")
	await _resolve_optional_dilemma()


func _resolve_optional_dilemma() -> void:
	var dilemma: CanvasLayer = _main.get_node("Dilemma")
	if not dilemma.visible:
		_check(not GameClock.paused, "shift returns control when no dilemma fires")
		return
	_check(GameClock.paused, "post-shift dilemma pauses the clock")
	var choice := _find_enabled_button(dilemma)
	_check(choice != null, "post-shift dilemma has an enabled choice")
	if choice == null:
		return
	choice.pressed.emit()
	await get_tree().process_frame
	_check(not dilemma.visible and not GameClock.paused,
			"choosing a dilemma result returns control")


func _find_descendant_of_type(node: Node, type) -> Node:
	if node == null:
		return null
	if is_instance_of(node, type):
		return node
	for child in node.get_children():
		var found := _find_descendant_of_type(child, type)
		if found != null:
			return found
	return null


func _find_enabled_button(node: Node) -> Button:
	if node is Button and not node.disabled:
		return node
	for child in node.get_children():
		var found := _find_enabled_button(child)
		if found != null:
			return found
	return null


func _hud_has_toast(needle: String) -> bool:
	var hud := _main.get_node_or_null("HUD")
	if hud == null:
		return false
	var toast_box := hud.get_node_or_null("%ToastBox")
	if toast_box == null:
		return false
	return _node_tree_has_label_text(toast_box, needle)


func _survival_feedback_kind() -> String:
	var feedback := _main.get_node_or_null("SurvivalFeedback")
	return str(feedback.get_meta("last_survival_kind", "")) if feedback != null else ""


func _survival_feedback_detail() -> String:
	var feedback := _main.get_node_or_null("SurvivalFeedback")
	return str(feedback.get_meta("last_survival_detail", "")) if feedback != null else ""


func _node_tree_has_label_text(node: Node, needle: String) -> bool:
	if node is Label and str(node.text).contains(needle):
		return true
	for child in node.get_children():
		if _node_tree_has_label_text(child, needle):
			return true
	return false


func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  PASS: %s" % what)
	else:
		failures += 1
		printerr("  FAIL: %s" % what)
