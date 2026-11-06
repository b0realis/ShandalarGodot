extends RefCounted
## Urza's Legacy (_auras, Pack 10). Auras: enchant a permanent and change it while attached.
##
## The shared helpers: cards/sets/mir/_auras.gd (A — host lookups, trigger
## host capture) and cards/sets/usg/_auras.gd (U — the self-returning
## Auras' leave trigger, [method U.returns_home], and the "upkeep of
## enchanted creature's controller" condition). Five of the block's eleven
## self-returning Auras are here: Cessation, Slow Motion, Sleeper's Guile,
## Sluggishness and Rancor — each comes back to its owner's hand whenever
## it is put into a graveyard from the battlefield, state-based actions
## included (CR 704.5m), and never when it is exiled instead.
##
## - Cessation / Sluggishness: the host's `cur_cant_attack` /
##   `cur_cant_block_filter`, written by the Aura's static (mir Pacifism).
## - Slow Motion: "that player sacrifices that creature unless they pay
##   {2}" — the creature as it was when the ability triggered (CR 400.7),
##   paid or sacrificed by the player whose upkeep it is, and only while
##   they still control it (CR 701.17a).
## - Treacherous Link: a static damage REDIRECT (engine/damage_replacements.gd,
##   CR 614.1a/616.1) from the enchanted creature to its controller as the
##   damage would be dealt.
## - Granite Grip: the Aura controller's Mountains, live subtype.
## tests/cards/test_pack_10_B7_*.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/mir/_auras.gd")
const U := preload("res://cards/sets/usg/_auras.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Cessation":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_cessation, "Enchanted creature can't attack."))
			U.returns_home(c)
		"Slow Motion":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _slow_motion,
				"At the beginning of the upkeep of enchanted creature's controller, that player sacrifices that creature unless they pay {2}.",
				U.host_controllers_upkeep).capturing(A.host_context))
			U.returns_home(c)
		"Sleeper's Guile":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FEAR]),
				"Enchanted creature has fear.").changing_abilities())
			U.returns_home(c)
		"Treacherous Link":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_treacherous_link,
				"All damage that would be dealt to enchanted creature is dealt to its controller instead."))
		"Granite Grip":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(U.per_land.bind("mountain", 1, 0),
				"Enchanted creature gets +1/+0 for each Mountain you control."))
		"Sluggishness":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_sluggishness, "Enchanted creature can't block."))
			U.returns_home(c)
		"Rancor":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(2, 0), "Enchanted creature gets +2/+0."))
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.TRAMPLE]),
				"Enchanted creature has trample.").changing_abilities())
			U.returns_home(c)
		_: return false
	return true


static func _anything(_i: CardInstance) -> bool: return true


static func _cessation(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i != null: i.cur_cant_attack = true


static func _sluggishness(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i != null: i.cur_cant_block_filter = _anything


# ---------------------------------------------------------------- Slow Motion --

## The upkeep's player pays; the hint (public state, their own pool and
## lands): keep a creature worth more than the {2} rent.
static func _slow_motion(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var i := A.trigger_host(g, s)
	var pid := int(e.data.get("player", g.active_player))
	if i == null or i.controller_id != pid: return
	var hint := i.cur_power + i.cur_toughness >= 3 \
		or (i.data.cost != null and i.data.cost.mana_value() >= 3)
	if EffectBase.unless_paid(g, pid, ManaCost.parse("{2}"),
			"Pay {2} to keep %s (Slow Motion)?" % i.data.card_name, hint):
		return
	if g.is_present(i) and i.controller_id == pid:
		g.sacrifice_permanent(i)


# ----------------------------------------------------------- Treacherous Link --

static func _treacherous_link(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null or not i.is_creature(): return
	g.add_static_damage_effect(s, {"kind": &"redirect", "victims": [i],
		"to": {"player": i.controller_id},
		"desc": "Treacherous Link: damage to %s is dealt to its controller instead" % i.data.card_name})
