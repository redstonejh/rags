extends Node
## Global signal hub. Signals only — no state lives here.
##
## Rule of thumb: use EventBus for "something happened that multiple unknown
## systems care about" (time passing, a crime, money changing). Use direct
## calls / "signal up, call down" for everything within a single scene.

# -- Time (emitted by GameClock, the single driver of all simulation) --
signal minute_passed(total_minutes: int)
signal hour_passed(hour: int)
signal day_passed(day: int)
signal time_scale_changed(scale: float)

# -- Player --
signal player_need_changed(need_id: String, value: float)
signal money_changed(cash_cents: int)
signal interact_target_changed(prompt: String) # "" when nothing in range
signal player_interacted(target: Node)
signal travel_requested(location_id: String)
signal player_location_changed(location_id: String)
