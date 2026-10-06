extends RefCounted
## Stronghold (_slivers, Pack 9). Slivers: creatures whose abilities every
## Sliver on the battlefield shares.
##
## The grants follow cards/sets/tmp/_slivers.gd (S): every Sliver on the
## battlefield, both players', re-derived on every recalculation; "All
## Slivers" reaches a Sliver that is not a creature too. A granted
## activated ability is the Sliver's own, so its sacrifice, bounce and
## damage are that Sliver's (the damage from its last known information,
## CR 608.2h, once it has been sacrificed).
##
## - Crystalline Sliver: shroud is a layer-6 grant (cur_shroud), so no
##   spell or ability targets a Sliver — its controller's included.
## - Spined Sliver: its OWN triggered ability, once per Sliver that becomes
##   blocked (BECOMES_BLOCKED, CR 509.3c). The bonus counts the creatures
##   blocking that Sliver — every creature blocking its band (CR 702.22)
##   — when the ability resolves, the rampage reading (CR 702.23); a
##   Sliver removed from combat or gone by then gets nothing.
## - Sliver Queen: a colourless 1/1 Sliver token, which every grant
##   reaches. Legendary (the 1997 legend rule buries the newer of two).
const F := preload("res://cards/sets/fem/_rules.gd")
const S := preload("res://cards/sets/tmp/_slivers.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Acidic Sliver":
			c.static_ability(StaticAbility.new(S.grant_ability.bind(ActivatedAbility.new("{2}", false,
					[DamageEffect.new(2).any_target()],
					"{2}, Sacrifice this permanent: This permanent deals 2 damage to any target.").with_sacrifice_cost(), false),
				"All Slivers have \"{2}, Sacrifice this permanent: This permanent deals 2 damage to any target.\"").changing_abilities())
		"Crystalline Sliver":
			c.static_ability(StaticAbility.new(_shroud, "All Slivers have shroud.").changing_abilities())
		"Hibernation Sliver":
			c.static_ability(StaticAbility.new(S.grant_ability.bind(ActivatedAbility.new("", false,
					[F.Action.new(S.return_self, "return this permanent to its owner's hand", null, true) \
						.with_ai_role(&"self_bounce")],
					"Pay 2 life: Return this permanent to its owner's hand.").with_life_cost(2), false),
				"All Slivers have \"Pay 2 life: Return this permanent to its owner's hand.\"").changing_abilities())
		"Sliver Queen":
			c.activated(ActivatedAbility.new("{2}", false, [CreateTokenEffect.new("Sliver", 1, 1, 0, "sliver")],
				"{2}: Create a 1/1 colorless Sliver creature token."))
		"Spined Sliver":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKED, _spined,
				"Whenever a Sliver becomes blocked, that Sliver gets +1/+1 until end of turn for each creature blocking it.",
				_a_sliver_blocked).capturing(_blocked_context))
		"Victual Sliver":
			c.static_ability(StaticAbility.new(S.grant_ability.bind(ActivatedAbility.new("{2}", false,
					[GainLifeEffect.new(4)], "{2}, Sacrifice this permanent: You gain 4 life.").with_sacrifice_cost(), false),
				"All Slivers have \"{2}, Sacrifice this permanent: You gain 4 life.\"").changing_abilities())
		_: return false
	return true


# -------------------------------------------------------- Crystalline Sliver --

static func _shroud(g: MtgGame, _s: CardInstance) -> void:
	for inst in g.all_battlefield():
		if S.is_sliver(inst, false):
			inst.cur_shroud = true


# ------------------------------------------------------------- Spined Sliver --

static func _a_sliver_blocked(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var body: CardInstance = e.data.get("instance")
	return body != null and body.has_subtype("sliver")

## "That Sliver" is the object the event named, found again on resolution
## only while it is still that object (CR 400.7).
static func _blocked_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var out := F._source_context(g, s, e)
	var body: CardInstance = e.data.get("instance")
	if body != null:
		out.merge({"sliver": body.id, "sliver_stamp": body.layer_timestamp})
	return out

static func _spined(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var body := g.find_instance(int(ctx.get("sliver", -1)))
	if not g.is_present(body) or body.layer_timestamp != int(ctx.get("sliver_stamp", -2)) \
			or not g.combat.attackers.has(body.id):
		return
	var count := g.combat.blockers_of_band(g.combat.band_of(body.id)).size()
	if count <= 0:
		return
	g.continuous.add_until_eot_pump(body.id, count, count)
	g.log_line("%s gets +%d/+%d until end of turn" % [body.data.card_name, count, count])
	g.recalculate()
