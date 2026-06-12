extends Node
## Read-only content database. Scans res://data/** at startup and indexes
## every .tres definition by its `id`. Definitions are never mutated at
## runtime and never saved — records reference them by string id.

const DATA_ROOT := "res://data"

var origins: Dictionary = {}
var traits: Dictionary = {}
var perks: Dictionary = {}
var items: Dictionary = {}
var archetypes: Dictionary = {}
var jobs: Dictionary = {}
var crimes: Dictionary = {}
var housings: Dictionary = {}
var furnitures: Dictionary = {}
var substances: Dictionary = {}

## class -> destination index
@onready var _index_for_type := {
	"OriginDef": origins,
	"TraitDef": traits,
	"PerkDef": perks,
	"ItemDef": items,
	"ArchetypeDef": archetypes,
	"JobDef": jobs,
	"CrimeDef": crimes,
	"HousingDef": housings,
	"FurnitureDef": furnitures,
	"SubstanceDef": substances,
}


func _ready() -> void:
	_scan_dir(DATA_ROOT)
	print("ContentDB: %d origins, %d traits, %d perks, %d items, %d archetypes" % [
		origins.size(), traits.size(), perks.size(), items.size(), archetypes.size()])


func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(full)
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			_register(load(full))
		entry = dir.get_next()
	dir.list_dir_end()


func _register(res: Resource) -> void:
	if res == null or not ("id" in res) or res.id == "":
		push_warning("ContentDB: skipping resource without id: %s" % res)
		return
	for type_name in _index_for_type:
		if res.get_script() and res.get_script().get_global_name() == type_name:
			var index: Dictionary = _index_for_type[type_name]
			if index.has(res.id):
				push_warning("ContentDB: duplicate id '%s' (%s)" % [res.id, type_name])
			index[res.id] = res
			return


func get_origin(id: String) -> OriginDef:
	return origins.get(id)


func get_trait(id: String) -> TraitDef:
	return traits.get(id)


func get_perk(id: String) -> PerkDef:
	return perks.get(id)


func get_item(id: String) -> ItemDef:
	return items.get(id)


func get_job(id: String) -> JobDef:
	return jobs.get(id)


func get_crime(id: String) -> CrimeDef:
	return crimes.get(id)


func get_housing(id: String) -> HousingDef:
	return housings.get(id)


func get_furniture(id: String) -> FurnitureDef:
	return furnitures.get(id)


func get_substance(id: String) -> SubstanceDef:
	return substances.get(id)


func all_housings() -> Array:
	var list := housings.values()
	list.sort_custom(func(a: HousingDef, b: HousingDef) -> bool:
		return a.tier < b.tier)
	return list


func all_furniture() -> Array:
	var list := furnitures.values()
	list.sort_custom(func(a: FurnitureDef, b: FurnitureDef) -> bool:
		return a.cost_cents < b.cost_cents)
	return list


func all_jobs() -> Array:
	var list := jobs.values()
	list.sort_custom(func(a: JobDef, b: JobDef) -> bool:
		return a.rung < b.rung if a.ladder_id == b.ladder_id else a.ladder_id < b.ladder_id)
	return list


func all_origins() -> Array:
	var list := origins.values()
	list.sort_custom(func(a: OriginDef, b: OriginDef) -> bool:
		return a.difficulty < b.difficulty or (a.difficulty == b.difficulty and a.display_name < b.display_name))
	return list


func all_traits() -> Array:
	var list := traits.values()
	# Positive (cost) traits first, then negative, alphabetical within.
	list.sort_custom(func(a: TraitDef, b: TraitDef) -> bool:
		if (a.point_cost >= 0) != (b.point_cost >= 0):
			return a.point_cost >= 0
		return a.display_name < b.display_name)
	return list
