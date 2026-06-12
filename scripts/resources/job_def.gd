class_name JobDef
extends Resource
## A job: where you stand, when you stand there, and what standing pays.
## Promotion chains link rungs via next_job_id (gated by skill + shifts).

@export var id: String = ""
@export var display_name: String = ""
@export var ladder_id: String = ""
@export var rung: int = 1
@export var workplace_id: String = ""
@export var wage_cents_per_shift: int = 0
@export var shift_start_hour: int = 9
@export var shift_len_hours: int = 8
## Days of week worked, 0 = Monday ... 6 = Sunday.
@export var work_days: Array = [0, 1, 2, 3, 4]
@export var requires_id: bool = true
## Background check: rejects "the_record" origins until the record seals.
@export var requires_clean_record: bool = false
## skill -> min level, e.g. {"cooking": 2}
@export var skill_reqs: Dictionary = {}
@export var min_shifts_for_promotion: int = 10
@export var next_job_id: String = ""
## Skill trained by working it, and XP per completed shift.
@export var trains_skill: String = ""
@export var skill_xp_per_shift: float = 4.0
@export_multiline var blurb: String = ""
