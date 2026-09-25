extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Lone Wolf", "Deathcoil Wurm": c.static_ability(StaticAbility.new(_bypass, "May assign combat damage as though unblocked."))
		"Cunning Giant": c.static_ability(StaticAbility.new(_redirect, "May assign unblocked combat damage to a defending creature."))
		"Piracy": c.spell(F.Action.new(_piracy, "you may tap opponents' lands for spell mana this turn", null, true).with_ai_role(&"borrow_land_mana"))
		"Relentless Assault": c.spell(F.Action.new(_assault, "untap creatures that attacked; add a combat and main phase", null, true).with_ai_role(&"additional_combat"))
		_: return false
	return true

static func _bypass(_g: MtgGame, s: CardInstance) -> void:
	s.cur_damage_as_unblocked = true

static func _redirect(_g: MtgGame, s: CardInstance) -> void:
	s.cur_unblocked_damage_to_creature = true

static func _piracy(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.continuous.add_floating_static(s, StaticAbility.new(_permission.bind(pid), "May tap foreign lands for spell mana."))
	g.recalculate()

static func _permission(g: MtgGame, _s: CardInstance, pid: int) -> void:
	if not g.foreign_land_mana.has(pid): g.foreign_land_mana.append(pid)

static func _assault(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and i.attacked_this_turn: g.untap_permanent(i)
	g.add_combat_after_current_main()
