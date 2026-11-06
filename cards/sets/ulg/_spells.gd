extends RefCounted
## Urza's Legacy (_spells, Pack 10). Instants and sorceries resolved by
## existing effects, typed wherever the engine has the shape (the fair AI
## reads them, engine/ai/effect_intent.gd); a card-local effect declares its
## shape through [member EffectBase.ai_role] for the Stage 4 policy. The
## predicates and the shared helpers are Urza's Saga's (usg/_spells.gd).
##
## - Peace and Quiet, Rack and Ruin, Sick and Tired: "two target X" is ONE
##   effect taking two different objects (CR 601.2c).
## - Intervene: a SPELL that targets a creature permanent (an Aura spell
##   aimed at one too); an ability is not a spell.
## - Tinker, Crop Rotation: the sacrifice is an additional cost, paid as the
##   spell is cast (CR 601.2h) — no artifact or land, no cast; the found
##   card enters the battlefield (a public find) and the library is
##   shuffled whether or not anything was found.
## - Ostracize: Duress's shape (usg/_spells.gd RevealedDiscard) for a
##   creature card.
## - Last-Ditch Effort: the sacrifice happens as it resolves, so a spell
##   whose target became illegal sacrifices nothing (CR 608.2b); the damage
##   is the number actually sacrificed.
## - Harmonic Convergence: every enchantment at once (one departure); each
##   OWNER orders their own cards on top of their library (CR 401.4), the
##   first one chosen ending on top.
## tests/cards/test_pack_10_B1_white_blue.gd, _black.gd, _red.gd,
## _green.gd and _ai.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const S := preload("res://cards/sets/usg/_spells.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Erase":
			c.spell(ExileEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment",
				S.P.enchantment)))
		"Peace and Quiet":
			var quiet := DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"two target enchantments", S.P.enchantment))
			quiet.target_min = 2
			quiet.target_max = 2
			c.spell(quiet)
		"Purify":
			c.spell(DestroyAllEffect.new("all artifacts and enchantments", S.P.artifact_or_enchantment))
		# ------------------------------------------------------------- blue
		"Intervene":
			var intervene := CounterEffect.new("target spell that targets a creature")
			intervene.target_spec.with_game_filter(_targets_a_creature)
			c.spell(intervene)
		"Opportunity": c.spell(DrawEffect.new(4).target_player())
		"Tinker":
			c.with_additional_sacrifice("artifact", S.P.artifact)
			c.spell(SearchLibraryEffect.new("an artifact card", S.P.artifact_card).to_battlefield())
		# ------------------------------------------------------------ black
		"Ostracize": c.spell(S.RevealedDiscard.new("creature", S.P.creature_card))
		"Sick and Tired": c.spell(S.U.two_targets(PumpEffect.new(-1, -1)))
		# -------------------------------------------------------------- red
		"About Face": c.spell(SwitchPowerToughnessEffect.new())
		"Last-Ditch Effort": c.spell(LastDitchEffort.new())
		"Rack and Ruin":
			var ruin := DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"two target artifacts", S.P.artifact))
			ruin.target_min = 2
			ruin.target_max = 2
			c.spell(ruin)
		# ------------------------------------------------------------ green
		"Crop Rotation":
			c.with_additional_sacrifice("land", S.P.land)
			c.spell(SearchLibraryEffect.new("a land card", S.P.land_card).to_battlefield())
		"Harmonic Convergence":
			c.spell(F.Action.new(_convergence, "put all enchantments on top of their owners' libraries") \
				.with_ai_role(&"enchantments_to_library_top"))
		"Might of Oaks": c.spell(PumpEffect.new(7, 7))
		"Silk Net": c.spell(PumpEffect.new(1, 1, [Mtg.Keyword.REACH]))
		"Wing Snare":
			c.spell(DestroyEffect.new(TargetSpec.creature("target creature with flying",
				S.P.flying_creature)))
		_: return false
	return true


## Intervene's spell: one whose targets include a creature on the
## battlefield (Vigilant Martyr's reading, mir/_creatures.gd).
static func _targets_a_creature(g: MtgGame, spell: CardInstance) -> bool:
	var item := g.find_stack_item(spell)
	if item == null or item.kind != Mtg.StackKind.SPELL: return false
	for ref in item.targets:
		if ref == null or ref.is_player: continue
		var aimed := g.find_instance(ref.instance_id)
		if aimed != null and aimed.zone == Mtg.Zone.BATTLEFIELD and aimed.is_creature(): return true
	return false


## Last-Ditch Effort: a DamageEffect whose amount is the creatures
## sacrificed as it resolves.
class LastDitchEffort extends DamageEffect:
	func _init() -> void:
		super(0)
		any_target()
		with_ai_role(&"sacrifice_creatures_damage")
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if t == null: return
		# Hint: just enough to finish an opposing target, none otherwise.
		var need := 0
		if t.is_player:
			if t.player_id != pid: need = g.players[t.player_id].life
		else:
			var victim := g.find_instance(t.instance_id)
			if victim != null and victim.controller_id != pid:
				need = maxi(victim.cur_toughness - victim.damage, 0)
		var bodies := 0
		for i in g.players[pid].battlefield:
			if g.is_present(i) and i.is_creature(): bodies += 1
		var n := S.U.sacrifice_any_number(g, pid, LastDitchEffort._creature, "creatures",
			s.data.card_name, need if need <= bodies else 0)
		if n > 0: g.deal_damage(s, t, n)
	static func _creature(i: CardInstance) -> bool:
		return i.is_creature()
	func describe() -> String:
		return "sacrifice any number of creatures; deals that much damage to any target"


static func _convergence(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var moving: Array[CardInstance] = []
	for p in S.U.apnap(g):
		var own: Array[CardInstance] = []
		for i in g.all_battlefield():
			if g.is_present(i) and S.P.enchantment(i) and i.owner_id == p: own.append(i)
		if own.is_empty(): continue
		var top_down := _order_top(g, p, own)
		top_down.reverse()   # the last one moved ends on top
		moving.append_array(top_down)
	g.depart_together(moving, g.return_permanent_to_library_top)


## Ask [param pid] to order [param cards] from the top down, one card at a
## time; the first answer ends on top. Hint: the costliest first (tmp/
## _choices.gd `_order_top`'s shape).
static func _order_top(g: MtgGame, pid: int, cards: Array[CardInstance]) -> Array[CardInstance]:
	var rest: Array[CardInstance] = cards.duplicate()
	rest.sort_custom(S.P.costliest_card_first)
	var ordered: Array[CardInstance] = []
	while rest.size() > 1:
		var next := g.agents[pid].choose_card_in_order(g, pid, rest,
			"Harmonic Convergence: choose the enchantment to put on top of your library (the next goes beneath it)")
		if next == null or not rest.has(next): next = rest[0]
		ordered.append(next)
		rest.erase(next)
	ordered.append_array(rest)
	return ordered
