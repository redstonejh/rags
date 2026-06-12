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

# -- Economy & life --
signal toast(message: String)                       # one-line narrator text
signal shift_started(job: JobDef, late_minutes: int)
signal shift_finished(job: JobDef, late_minutes: int)
signal shift_dilemma(dilemma: Dictionary)           # post-shift moment; UI presents choices
signal shop_opened(stock: Array)
signal path_updated                                 # life-path step changed
signal player_died(cause: String)
signal player_job_changed(job_id: String)

# -- Social & perception (M4) --
signal dialogue_requested(npc_id: String)           # player wants to talk
signal relationship_changed(npc_id: String, value: float)
signal reality_check(perceived: float, actual: float, npc_id: String)

# -- Crime & consequences (M5) --
signal crime_committed(case_id: String)
signal crime_witnessed(npc_id: String, case_id: String)
signal warrant_issued(case_id: String)
signal wanted_changed(stars: int)
signal arrest_made(sentence_days: int)
signal confrontation_started(payload: Dictionary)   # {kind, npc_id, text}
signal npc_died(npc_id: String, cause: String)
