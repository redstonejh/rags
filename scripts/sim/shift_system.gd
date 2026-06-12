class_name ShiftSystem
extends Node
## Pays the player for completed shifts, trains the job's skill, counts
## shifts toward promotion, and occasionally fires a workplace dilemma.
## Plain Node in Main.tscn (not an autoload) — listens to EventBus only,
## so headless tests can drive it by emitting shift_finished directly.

const LATE_GRACE_MINUTES := 30
const LATE_PENALTY_MULT := 0.75
const DILEMMA_CHANCE := 0.25

## Small code table: each dilemma is a post-shift moment with 2-3 choices.
## Choices apply cash (clean cents) and need deltas; the result line toasts.
const DILEMMAS := [
	{
		"text": "The till is $20 short and Carl is sweating. Management is doing the math out loud.",
		"choices": [
			{"label": "Cover it quietly", "cash": -2000, "needs": {"social": 10.0},
				"result": "Carl owes you one. Carl will forget this."},
			{"label": "Rat out Carl", "cash": 0, "needs": {"social": -10.0},
				"result": "Carl is gone by Friday. The kitchen goes quiet when you walk in."},
			{"label": "Shrug", "cash": 0, "needs": {"fun": -4.0},
				"result": "It becomes, somehow, everyone's problem but yours."},
		],
	},
	{
		"text": "The closer called in \"sick.\" Through the phone you could hear a party. The boss looks at you.",
		"choices": [
			{"label": "Take the extra hours", "cash": 2500, "needs": {"energy": -20.0},
				"result": "Time-and-a-little. Your feet file a complaint."},
			{"label": "You also feel sick, suddenly", "cash": 0, "needs": {"social": -6.0},
				"result": "The boss writes something in a small notebook."},
		],
	},
	{
		"text": "A regular slips you a folded bill and says you remind them of someone dead.",
		"choices": [
			{"label": "Pocket it", "cash": 1200, "needs": {},
				"result": "It goes in your sock. Tradition."},
			{"label": "Split it with the crew", "cash": 400, "needs": {"social": 8.0},
				"result": "Cheap goodwill is still goodwill."},
		],
	},
	{
		"text": "You broke something expensive. There were no witnesses except the security camera everyone forgets is fake.",
		"choices": [
			{"label": "Confess", "cash": -1000, "needs": {"social": 4.0},
				"result": "Docked, but the boss respects it. Probably."},
			{"label": "Blame the new guy", "cash": 0, "needs": {"fun": -6.0, "social": -4.0},
				"result": "The new guy lasts one more day. You learn nothing."},
		],
	},
]


func _ready() -> void:
	EventBus.shift_finished.connect(_on_shift_finished)


static func paycheck_result(sheet: CharacterSheet, job: JobDef, late_minutes: int) -> Dictionary:
	if job == null:
		return {"wage_cents": 0, "docked": false, "garnished": false}
	var wage := job.wage_cents_per_shift
	var docked := late_minutes > LATE_GRACE_MINUTES
	if docked:
		wage = int(wage * LATE_PENALTY_MULT)
	var garnished := sheet != null and sheet.has_tag("garnished")
	if garnished:
		wage = int(wage * 0.75)
	return {"wage_cents": wage, "docked": docked, "garnished": garnished}


static func paycheck_summary(result: Dictionary) -> String:
	return "$%.2f%s%s" % [
		int(result.get("wage_cents", 0)) / 100.0,
		" - docked 25%% for strolling in late" if result.get("docked", false) else "",
		" (25%% garnished. Forever.)" if result.get("garnished", false) else ""]


func _on_shift_finished(job: JobDef, late_minutes: int) -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null or job == null:
		return
	var paycheck := paycheck_result(sheet, job, late_minutes)
	var wage := int(paycheck.get("wage_cents", 0))
	sheet.add_cash(wage)
	sheet.shifts_worked += 1
	sheet.add_xp(10)
	if job.trains_skill != "":
		sheet.add_skill_xp(job.trains_skill, job.skill_xp_per_shift)
	EventBus.toast.emit("Clocked out. %s" % paycheck_summary(paycheck))
	_check_promotion(sheet, job)
	if randf() < DILEMMA_CHANCE:
		EventBus.shift_dilemma.emit(DILEMMAS.pick_random())


## Shifts >= minimum and the next rung's skill bar met -> the boss mentions it.
## Actually taking the job happens on the phone, like everything else in life.
func _check_promotion(sheet: CharacterSheet, job: JobDef) -> void:
	if job.next_job_id == "" or sheet.shifts_worked < job.min_shifts_for_promotion:
		return
	var next := ContentDB.get_job(job.next_job_id)
	if next == null:
		return
	for skill in next.skill_reqs:
		if sheet.skill_level(skill) < int(next.skill_reqs[skill]):
			return
	var flag := "promo_offered_" + next.id
	if sheet.flags.get(flag, false):
		return
	sheet.flags[flag] = true
	EventBus.toast.emit("The boss pulls you aside: \"%s. Interested?\" (Apply on your phone.)" % next.display_name)
