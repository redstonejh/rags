class_name CrimeDef
extends Resource
## A crime, as the law and the gossip network see it. ~Severity 1-10 from
## jaywalking to murder. Evidence on murder cases never decays.

@export var id: String = ""
@export var display_name: String = ""
## What a witness says they saw: "saw you lift a wallet".
@export var witness_text: String = ""
@export_range(1, 10) var severity: int = 1
## Evidence points an OPEN case loses per day (0 = never; murder).
@export var evidence_decay_per_day: float = 5.0
## How juicy this is at the bar (memory salience for witnesses).
@export var gossip_salience: float = 6.0
@export var sentence_days_min: int = 1
@export var sentence_days_max: int = 3
@export var bailable: bool = true
