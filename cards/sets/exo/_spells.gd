extends RefCounted
## Exodus (_spells, Pack 9). Instants and sorceries: one-shot spell effects, modes, X spells and their targets.
##
## - Kor Chant: two targets — "target creature you control" and "another
##   target creature" (different objects, CR 115.3) — and a source chosen as
##   the spell resolves (CR 609.7a). The redirection is one entry of the
##   damage replacement suite (MtgGame.add_damage_effect, kind redirect,
##   for the turn): ALL damage that source would deal to the first creature
##   this turn is dealt to the second instead (CR 614.9), each event once
##   (CR 614.5). Both effects carry is_damage_prevention: a redirection is
##   one of the three families the 1997 damage-prevention window allows.
## - Fighting Chance: one flip per blocking creature, by the caster
##   (CR 705.1), each win a one-creature combat fog for the turn; legal in
##   the 1997 window too.
## - Fade Away: the creatures are counted per player as it resolves; each
##   player in APNAP order answers {1}-or-sacrifice once per creature, then
##   every chosen permanent is sacrificed in one event.
## - Resuscitate: the ability goes to the creatures you control AS IT
##   RESOLVES (a creature arriving later gets nothing, CR 611.2c), until end
##   of turn.
## tests/cards/test_pack_9_B12_spells.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Death's Duet":
			var duet := ReturnFromGraveyardEffect.new()
			duet.target_spec.description = "two target creature cards in your graveyard"
			duet.target_min = 2
			duet.target_max = 2
			c.spell(duet)
		"Fade Away":
			c.spell(F.Action.new(_fade_away,
				"for each creature, its controller sacrifices a permanent of their choice unless they pay {1}") \
				.with_ai_role(&"creature_tax_sweep"))
		"Fighting Chance":
			c.spell(F.Action.new(_fighting_chance,
				"for each blocking creature, flip a coin; on a win, prevent all combat damage it would deal this turn", null, true) \
				.as_damage_prevention().with_ai_role(&"coin_fog_blockers"))
		"Fugue":
			c.spell(F.Action.new(_fugue, "target player discards three cards", TargetSpec.player()) \
				.with_ai_role(&"discard", {"count": 3}))
		"Kor Chant":
			var guarded := KorChantMark.new()
			c.spell(guarded)
			c.spell(KorChantRedirect.new(guarded.target_spec))
		"Nausea":
			c.spell(MassPumpEffect.new(-1, -1, "all creatures"))
		"Price of Progress":
			c.spell(F.Action.new(_price_of_progress,
				"deals damage to each player equal to twice the number of nonbasic lands that player controls") \
				.with_ai_role(&"nonbasic_land_tax"))
		"Reclaim":
			c.spell(ReclaimEffect.new())
		"Resuscitate":
			c.spell(F.Action.new(_resuscitate,
				"until end of turn, creatures you control gain \"{1}: Regenerate this creature.\"", null, true) \
				.with_ai_role(&"team_regeneration"))
		"Scare Tactics":
			c.spell(MassPumpEffect.new(1, 0, "creatures you control").yours_only())
		_: return false
	return true


## APNAP order (CR 101.4): the active player first.
static func _apnap(g: MtgGame) -> Array[int]:
	var out: Array[int] = []
	for k in g.players.size():
		out.append((g.active_player + k) % g.players.size())
	return out

static func _worth(i: CardInstance) -> int:
	var w := i.data.cost.mana_value()
	if i.is_creature(): w += maxi(i.cur_power, 0) + maxi(i.cur_toughness, 0)
	if i.is_land(): w += 3
	return w


# --------------------------------------------------------------- Fade Away --

static func _fade_away(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var doomed: Array[CardInstance] = []
	for who in _apnap(g):
		var creatures := 0
		for i in g.players[who].battlefield:
			if i.is_creature(): creatures += 1
		for n in creatures:
			if EffectBase.unless_paid(g, who, ManaCost.parse("{1}"),
					"Fade Away: pay {1}, or sacrifice a permanent (%d of %d)?" % [n + 1, creatures]):
				continue
			var left: Array[CardInstance] = []
			for i in g.players[who].battlefield:
				if not doomed.has(i): left.append(i)
			if left.is_empty(): break
			# The cheapest first: a heuristic seat gives up the least.
			left.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
				var wa := _worth(a)
				var wb := _worth(b)
				return wa < wb if wa != wb else a.id < b.id)
			var pick := g.agents[who].choose_card(g, who, left,
				"Fade Away: choose a permanent to sacrifice", false, false, true)
			if pick == null or not left.has(pick): pick = left[0]
			doomed.append(pick)
	if doomed.is_empty(): return
	g.begin_simultaneous()
	for i in doomed:
		if g.is_present(i): g.sacrifice_permanent(i)
	g.end_simultaneous()


# --------------------------------------------------------- Fighting Chance --

static func _fighting_chance(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var blockers: Array[CardInstance] = []
	for i in g.all_battlefield():
		if i.is_creature() and g.combat.blocks.has(i.id): blockers.append(i)
	for i in blockers:
		if g.flip_coin(pid):
			g.continuous.add_until_eot_combat_prevention(i.id, true, false)
			g.log_line("Fighting Chance: %s's combat damage is prevented this turn" % i.data.card_name)
	g.recalculate()


# ------------------------------------------------------------------- Fugue --

## "Target player discards three cards" — that player chooses (CR 701.8a).
static func _fugue(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if t == null or not t.is_player: return
	var who := t.player_id
	var hand := g.players[who].hand
	if hand.is_empty(): return
	var count := mini(3, hand.size())
	var picked := g.agents[who].choose_discard(g, who, count)
	var thrown: Array[CardInstance] = []
	for card in picked:
		if hand.has(card) and not thrown.has(card): thrown.append(card)
	for card in hand:
		if thrown.size() >= count: break
		if not thrown.has(card): thrown.append(card)
	g.discard_cards(who, thrown)


# ---------------------------------------------------------------- Kor Chant --

## The first target: the creature the damage would have hit. It does
## nothing itself; the redirection reads it (MtgGame.current_targets).
class KorChantMark extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("target creature you control").with_source_filter(_yours).because("controller")
		is_damage_prevention = true
		ai_helpful = true
	static func _yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return s != null and i.controller_id == g.controller_acting_for(s)
	func resolve(_g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		pass
	func describe() -> String:
		return "names target creature you control"

## The second target and the work: skipped when it is illegal (nothing to
## send the damage to); otherwise the first target is re-judged here, and
## only a legal one is protected.
class KorChantRedirect extends EffectBase:
	var first_spec: TargetSpec
	func _init(first: TargetSpec) -> void:
		first_spec = first
		target_spec = TargetSpec.creature("another target creature") \
			.with_sibling_filter(_distinct, TargetSpec.WHY["cant_target"])
		is_damage_prevention = true
		with_ai_role(&"redirect_source_damage")
	static func _distinct(_g: MtgGame, _s: CardInstance, candidate: TargetRef, earlier: Array) -> bool:
		for ref in earlier:
			if ref != null and not ref.is_player and not candidate.is_player \
					and ref.instance_id == candidate.instance_id:
				return false
		return true
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var refs := g.current_targets()
		if refs.is_empty() or refs[0] == null or t == null: return
		if not first_spec.is_legal(g, refs[0], s, [], pid): return
		var guarded := g.find_instance(refs[0].instance_id)
		var to := g.find_instance(t.instance_id)
		if not g.is_present(guarded) or not g.is_present(to): return
		var named := g.choose_damage_source(pid, "Kor Chant: Select a source.", Callable(),
			TargetRef.card(guarded))
		if named == null:
			g.log_line("Kor Chant: nothing to name as a source, nothing happens")
			return
		g.add_damage_effect({"kind": &"redirect", "controller": pid, "card": "Kor Chant",
			"source": named, "victims": [guarded], "to": TargetRef.card(to),
			"desc": "Kor Chant: damage %s would deal to %s is dealt to %s instead" % [
				named.data.card_name, guarded.data.card_name, to.data.card_name]})
		g.log_line("Kor Chant: damage from %s to %s goes to %s this turn" % [
			named.data.card_name, guarded.data.card_name, to.data.card_name])
	func describe() -> String:
		return "all damage a source of your choice would deal to the first creature this turn is dealt to another target creature instead"


# -------------------------------------------------------- Price of Progress --

## One damage event (CR 120.3): every player is dealt their share at once.
static func _price_of_progress(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var hits := {}
	for who in _apnap(g):
		var n := 0
		for i in g.players[who].battlefield:
			if i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) == 0: n += 1
		if n > 0: hits[who] = 2 * n
	if hits.is_empty(): return
	g.begin_simultaneous()
	for who in hits: g.deal_damage(s, TargetRef.player(int(who)), int(hits[who]))
	g.end_simultaneous()


# ----------------------------------------------------------------- Reclaim --

## "Put target card from your graveyard on top of your library."
class ReclaimEffect extends ReturnFromGraveyardEffect:
	func _init() -> void:
		super()
		any_card()
		ai_helpful = true
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i != null: g.return_from_graveyard_to_library_top(i)
	func describe() -> String:
		return "put target card from your graveyard on top of your library"


# ------------------------------------------------------------- Resuscitate --

static func _resuscitate(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for i in g.players[pid].battlefield:
		if not i.is_creature(): continue
		g.continuous.add_granted_activated_ability(i.id, ActivatedAbility.new("{1}", false,
			[RegenerateEffect.new()], "{1}: Regenerate this creature."), ContinuousEffects.Duration.END_OF_TURN)
	g.recalculate()
