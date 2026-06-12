class_name TownLife
extends Node
## The town is a story machine even if you never touch it. Daily: NPCs fall
## in love, feud, get promoted, get mugged — each event is a Gazette
## headline. Holidays come around. Elections happen, and you can buy one.
## Plain Node in Main.tscn.

const EVENTS_PER_DAY := 3
const ELECTION_PERIOD_DAYS := 30
const MAYOR_WEEKLY_SALARY := 50000
const CAMPAIGN_SCORE_PER_DOLLAR := 5.0 / 1000.0  # +5 per $1,000
const INCUMBENT_SCORE := 30.0

## Day-of-cycle -> holiday (35-day "month"). Each has one mechanical hook.
const HOLIDAYS := {
	10: "FOUNDER'S DAY",   # the fair: pickpocket paradise
	20: "GRISTMAS",        # gift-giving: relationship windfalls
	30: "ALL HALLOWS",     # masks are normal for one night
}


static func holiday_today() -> String:
	return HOLIDAYS.get(GameClock.day % 35, "")


func _ready() -> void:
	EventBus.day_passed.connect(_on_day_passed)
	EventBus.warrant_issued.connect(_on_warrant_issued)
	EventBus.npc_died.connect(_on_npc_died)


func _on_day_passed(day: int) -> void:
	# Fear cools one degree a day. The town wants to forget.
	WorldState.town_fear = maxf(WorldState.town_fear - 1.0, 0.0)
	var holiday := holiday_today()
	if holiday != "":
		WorldState.add_news("%s. %s" % [holiday, _holiday_flavor(holiday)])
		if holiday == "GRISTMAS" and WorldState.player_sheet != null:
			WorldState.player_sheet.needs.change("fun", 10.0)
			WorldState.player_sheet.needs.change("social", 10.0)
	for _i in EVENTS_PER_DAY:
		_random_event()
	_business_day()
	if day % ELECTION_PERIOD_DAYS == 0:
		_election_day()
	if day % 7 == 0 and WorldState.player_sheet != null \
			and WorldState.player_sheet.flags.get("is_mayor", false):
		WorldState.player_sheet.add_cash(MAYOR_WEEKLY_SALARY)
		EventBus.toast.emit("Mayoral salary: $500. Public service pays. That's the problem.")


static func _holiday_flavor(holiday: String) -> String:
	match holiday:
		"FOUNDER'S DAY": return "The fair is in town. So is every pickpocket who can walk."
		"GRISTMAS": return "Gift-giving, loneliness, and retail hell-shifts. The lights are nice."
		"ALL HALLOWS": return "Masks are normal for one night. The police know exactly what that means."
	return ""


# ------------------------------------------------------------- npc events

func _random_event() -> void:
	var pool: Array = []
	for npc in WorldState.npcs.values():
		if npc.alive:
			pool.append(npc)
	if pool.size() < 2:
		return
	var a: NPCRecord = pool.pick_random()
	var b: NPCRecord = pool.pick_random()
	if a == b:
		return
	match randi() % 6:
		0: # romance
			a.change_rel(b.id, 25.0)
			b.change_rel(a.id, 25.0)
			WorldState.add_news("%s and %s were seen sharing a milkshake at Mel's. The town approves, loudly." % [
					a.display_name.get_slice(" ", 0), b.display_name.get_slice(" ", 0)])
		1: # feud
			a.change_rel(b.id, -30.0)
			b.change_rel(a.id, -30.0)
			WorldState.add_news("A dispute over %s has ended the friendship of %s and %s." % [
					["a parking spot", "a borrowed ladder", "a casserole dish", "fourteen dollars"][randi() % 4],
					a.display_name, b.display_name])
		2: # promotion
			a.money_cents += 5000
			a.add_memory("promotion", a.id, "got promoted", 0.8, 5.0)
			WorldState.add_news("%s was promoted at %s. Drinks were had." % [
					a.display_name, Locations.display_name(a.workplace_id) if a.workplace_id != "" else "work"])
		3: # NPC crime: the town generates its own police blotter
			if int(a.personality.get("greed", 50)) > 55 and a != b:
				var take: int = mini(b.money_cents, 2500)
				b.money_cents -= take
				a.money_cents += take
				b.add_memory("mugged", a.id, "mugged you in the alley", -0.9, 8.0)
				WorldState.town_fear = minf(WorldState.town_fear + 2.0, 100.0)
				WorldState.add_news("MUGGING ON THE %s SIDE: residents report a figure, a demand, and the usual outcome." % \
						["EAST", "WEST", "DOCK", "WRONG"][randi() % 4])
		4: # small fortune
			a.money_cents += 2000
			WorldState.add_news("%s won at cards behind the Rusty Anchor and told absolutely everyone." % a.display_name)
		5: # gossip burst: a juicy memory travels for free
			GossipSystem.share(a, b)


# ------------------------------------------------------------- businesses

## Owned businesses pay daily and launder dirty money at 80 cents on the
## dollar — that's WHY the criminal buys the laundromat.
const BUSINESSES := {
	"laundromat": {"name": "Suds City Laundromat", "cost": 2500000, "net": 6000, "wash_cap": 50000},
	"corner_store": {"name": "The Corner Store", "cost": 6000000, "net": 15000, "wash_cap": 120000},
}
const WASH_RATE := 0.8


func _business_day() -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet == null or not sheet.alive:
		return
	for biz_id in sheet.flags.get("businesses", []):
		var biz: Dictionary = BUSINESSES.get(biz_id, {})
		if biz.is_empty():
			continue
		var net := int(biz.net)
		if WorldState.town_fear >= 60.0:
			net /= 2 # terror is bad for the casino, and everything else
		sheet.add_cash(net)
		var wash: int = mini(int(biz.wash_cap), sheet.dirty_cents)
		if wash > 0:
			sheet.add_dirty_cash(-wash)
			sheet.add_cash(int(wash * WASH_RATE))


static func buy_business(sheet: CharacterSheet, biz_id: String) -> bool:
	var biz: Dictionary = BUSINESSES.get(biz_id, {})
	if biz.is_empty():
		return false
	var owned: Array = sheet.flags.get("businesses", [])
	if biz_id in owned or sheet.cash_cents < int(biz.cost):
		return false
	sheet.add_cash(-int(biz.cost))
	owned.append(biz_id)
	sheet.flags["businesses"] = owned
	sheet.fame = clampf(sheet.fame + 5.0, 0.0, 100.0)
	WorldState.add_news("LOCAL BUSINESS SOLD: %s has a new owner with big plans and a clean smile." % biz.name)
	EventBus.toast.emit("You own %s now. The books are beautiful. Both sets." % biz.name)
	return true


# -------------------------------------------------------------- elections

func _election_day() -> void:
	var sheet: CharacterSheet = WorldState.player_sheet
	if sheet != null and sheet.alive and sheet.flags.get("candidate", false):
		var score := player_election_score(sheet)
		sheet.flags.erase("candidate")
		if score > INCUMBENT_SCORE:
			sheet.flags["is_mayor"] = true
			sheet.fame = clampf(sheet.fame + 15.0, 0.0, 100.0)
			WorldState.add_news("UPSET AT CITY HALL: %s elected mayor. The donor list is, quote, 'being finalized'." % sheet.char_name)
			EventBus.toast.emit("You won. Mayor %s. Nobody audits the winner." % sheet.char_name.get_slice(" ", 0))
		else:
			WorldState.add_news("INCUMBENT HOLDS CITY HALL; challenger %s concedes, bitterly." % sheet.char_name)
			EventBus.toast.emit("You lost. The yard signs are yours to keep.")
	else:
		WorldState.add_news("ELECTION NIGHT: the mayor remains the mayor. Turnout described as 'technically nonzero'.")


## Fame sells, infamy scares, and money talks at $1,000 a point of talk.
static func player_election_score(sheet: CharacterSheet) -> float:
	return sheet.fame - sheet.infamy * 0.5 \
			+ float(sheet.flags.get("campaign_spend", 0)) * CAMPAIGN_SCORE_PER_DOLLAR / 100.0


static func donate_to_campaign(sheet: CharacterSheet, cents: int) -> bool:
	# Dirty money welcome — that's the whole point of local politics.
	if sheet.cash_cents + sheet.dirty_cents < cents:
		return false
	var from_dirty: int = mini(sheet.dirty_cents, cents)
	if from_dirty > 0:
		sheet.add_dirty_cash(-from_dirty)
	if cents - from_dirty > 0:
		sheet.add_cash(-(cents - from_dirty))
	sheet.flags["candidate"] = true
	sheet.flags["campaign_spend"] = int(sheet.flags.get("campaign_spend", 0)) + cents
	return true


# ------------------------------------------------------------------ press

func _on_warrant_issued(case_id: String) -> void:
	var case: CrimeCase = WorldState.crime_cases.get(case_id)
	if case == null:
		return
	var def := case.def()
	WorldState.add_news("WARRANT ISSUED in %s case. Police describe the suspect as 'known to them'." % \
			(def.display_name.to_lower() if def else "an ongoing"))


func _on_npc_died(npc_id: String, cause: String) -> void:
	var npc: NPCRecord = WorldState.npcs.get(npc_id)
	if npc == null:
		return
	if cause == "old age":
		WorldState.add_news("OBITUARY: %s, %d, died peacefully. The diner is naming a sandwich after them." % [
				npc.display_name, int(npc.age_years)])
	else:
		WorldState.town_fear = minf(WorldState.town_fear + 8.0, 100.0)
		WorldState.add_news("%s FOUND DEAD. Police are 'pursuing leads'. Doors are being locked that never were." % npc.display_name.to_upper())
