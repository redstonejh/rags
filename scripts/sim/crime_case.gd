class_name CrimeCase
extends RefCounted
## A crime as the police know it. perpetrator_id is ground truth;
## suspect_id is what they BELIEVE — the gap between the two is where
## framing and getting-away-with-it live. Warrant at evidence >= 60.

const UNREPORTED := "UNREPORTED"
const OPEN := "OPEN"
const WARRANT := "WARRANT"
const COLD := "COLD"
const CLOSED := "CLOSED"

const WARRANT_EVIDENCE := 60.0

var id: String = ""
var crime_id: String = ""
var perpetrator_id: String = "player"
var suspect_id: String = ""        # "" = police have nobody
var evidence: float = 0.0          # 0-100
var status: String = UNREPORTED
var day: int = 0
var location_id: String = ""
var witness_ids: Array = []
var spawned_by_case_id: String = ""


func def() -> CrimeDef:
	return ContentDB.get_crime(crime_id)


func is_active_warrant() -> bool:
	return status == WARRANT and suspect_id == "player"


func to_dict() -> Dictionary:
	return {
		"id": id, "crime_id": crime_id,
		"perpetrator_id": perpetrator_id, "suspect_id": suspect_id,
		"evidence": evidence, "status": status, "day": day,
		"location_id": location_id, "witness_ids": witness_ids.duplicate(),
		"spawned_by_case_id": spawned_by_case_id,
	}


static func from_dict(d: Dictionary) -> CrimeCase:
	var c := CrimeCase.new()
	c.id = d.get("id", "")
	c.crime_id = d.get("crime_id", "")
	c.perpetrator_id = d.get("perpetrator_id", "player")
	c.suspect_id = d.get("suspect_id", "")
	c.evidence = float(d.get("evidence", 0.0))
	c.status = d.get("status", UNREPORTED)
	c.day = int(d.get("day", 0))
	c.location_id = d.get("location_id", "")
	c.witness_ids = d.get("witness_ids", []).duplicate()
	c.spawned_by_case_id = str(d.get("spawned_by_case_id", ""))
	return c
