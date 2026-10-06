extends RefCounted
## Stronghold (_licids, Pack 9). Licids: creatures that become Auras
## attached to a creature until their controller pays to end the effect.
##
## The conventions are cards/sets/tmp/_licids.gd's: E3's
## CardData.as_licid first, then every other line as the same line on a
## real Aura, keyed to the licid's `attached_to` (it does nothing while the
## licid is a creature).
##
## - Calming Licid: "can't attack" (cur_cant_attack); Convulsing Licid:
##   "can't block" (cur_cant_block_filter) — Pacifism's two halves.
## - Corrupting Licid's fear and Gliding Licid's flying are layer-6 grants.
## - Tempting Licid is Lure (cards/sets/2ed/lure.gd): every creature able to
##   block the enchanted creature does so.
const A := preload("res://cards/sets/mir/_auras.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Calming Licid":
			c.as_licid("{W}", "{W}")
			c.static_ability(StaticAbility.new(_calm, "Enchanted creature can't attack."))
		"Convulsing Licid":
			c.as_licid("{R}", "{R}")
			c.static_ability(StaticAbility.new(_convulse, "Enchanted creature can't block."))
		"Corrupting Licid":
			c.as_licid("{B}", "{B}")
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FEAR]),
				"Enchanted creature has fear.").changing_abilities())
		"Gliding Licid":
			c.as_licid("{U}", "{U}")
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FLYING]),
				"Enchanted creature has flying.").changing_abilities())
		"Tempting Licid":
			c.as_licid("{G}", "{G}")
			c.static_ability(StaticAbility.new(_tempt, "All creatures able to block enchanted creature do so."))
		_: return false
	return true


static func _anything(_i: CardInstance) -> bool:
	return true

static func _calm(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i != null: i.cur_cant_attack = true

static func _convulse(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i != null: i.cur_cant_block_filter = _anything

static func _tempt(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i != null:
		i.cur_must_be_blocked = true
		i.cur_must_be_blocked_by_all = true   # every creature, not a narrowed few
