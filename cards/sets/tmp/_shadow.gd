extends RefCounted
## Tempest (_shadow, Pack 9). Shadow (CR 702.28): creatures that can block or be blocked only by creatures with shadow, and the cards that grant or answer it.
##
## Batch B1 — every card here is a thin declaration over the Pack 9 E1
## engine package (the shadow keyword, CR 702.28):
## - SHADOW is `Mtg.Keyword.SHADOW`. A printed shade gets it from
##   [method shadow] (once, whatever the scaffold already says); the
##   blocking rule is the engine's ([method CombatState.block_illegality],
##   both directions, LIVE keywords, checked only as blockers are declared —
##   CR 506.4), so a creature card here never touches combat itself.
## - GRANTED shadow is an until-end-of-turn keyword grant (`PumpEffect`
##   0/0 carrying SHADOW — Jump's shape): Shadow Rift, Dauthi Embrace,
##   Soltari Emissary; LOST shadow is `LoseAbilityEffect` (Reality Anchor).
##   Layer 6 runs in timestamp order, so a later grant beats an earlier loss.
## - "A creature with shadow" is the live keyword ([method has_shadow]):
##   Shadowstorm, Circle of Protection: Shadow, Maze of Shadows, Phyrexian
##   Splicer's shadow row. Dauthi Ghoul reads the dead creature's LAST KNOWN
##   keywords (CR 608.2h, `CardInstance.had_keyword`).
## - "Can block creatures with shadow as though it had shadow" (Heartwood
##   Dryad, Wall of Diffusion) is E1's printed static
##   ([method CombatState.blocks_shadow]); the creature does NOT have shadow.
## The Stronghold and Exodus shadow modules (cards/sets/sth/_shadow.gd,
## cards/sets/exo/_shadow.gd) share the helpers below. A triggered ability
## resolves for the seat that controlled it when it triggered (CR 603.3a,
## [method pid_of]); "this creature" clauses act only on the same object
## (CR 400.7). tests/cards/test_pack_9_B1_*.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const MC := preload("res://cards/sets/mir/_combat.gd")

## Phyrexian Splicer's four choices (CR 602.2b: the choice is announced
## with the activation, so each is its own activation row).
const SPLICED := [
	[Mtg.Keyword.FLYING, "flying"],
	[Mtg.Keyword.FIRST_STRIKE, "first strike"],
	[Mtg.Keyword.TRAMPLE, "trample"],
	[Mtg.Keyword.SHADOW, "shadow"],
]


static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------- printed shadow only
		"Dauthi Marauder", "Soltari Foot Soldier", "Thalakos Sentry":
			shadow(c)
		"Soltari Monk", "Soltari Priest":
			# The scaffold prints the protection (black / red).
			shadow(c)
		# ------------------------------------------------------------ white
		"Circle of Protection: Shadow":
			# The Circle of Protection family (PreventDamageShieldEffect): the
			# source is named as the ability resolves — a creature with
			# shadow, read live (CR 609.7a) — and the 1997 damage-prevention
			# window takes the waiting packet instead (is_damage_prevention).
			c.activated(ActivatedAbility.new("{1}", false,
				[PreventDamageShieldEffect.new(0).from_sources("a creature with shadow", _shadow_creature_source)],
				"{1}: The next time a creature of your choice with shadow would deal damage to you this turn, prevent that damage."))
		"Soltari Crusader":
			shadow(c)
			c.activated(ActivatedAbility.new("{1}{W}", false, [PumpEffect.new(1, 0).self_buff()],
				"{1}{W}: This creature gets +1/+0 until end of turn."))
		"Soltari Emissary":
			# Role `self_keyword` (Manta Riders' reading): an attacker that
			# lacks shadow buys it before blocks.
			c.activated(ActivatedAbility.new("{W}", false,
				[PumpEffect.new(0, 0, [Mtg.Keyword.SHADOW]).self_buff() \
					.with_ai_role(&"self_keyword", {"keyword": Mtg.Keyword.SHADOW})],
				"{W}: This creature gains shadow until end of turn."))
		"Soltari Lancer":
			shadow(c)
			c.static_ability(StaticAbility.new(_first_strike_attacking,
				"This creature has first strike as long as it's attacking.").changing_abilities())
		"Soltari Trooper":
			shadow(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _trooper,
				"Whenever this creature attacks, it gets +1/+1 until end of turn.", F._self_attack))
		# ------------------------------------------------------------- blue
		"Shadow Rift":
			c.spell(PumpEffect.new(0, 0, [Mtg.Keyword.SHADOW]))
			c.spell(DrawEffect.new(1))
		"Thalakos Dreamsower":
			shadow(c)
			c.with_may_skip_untap()
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _dreamsower,
				"Whenever this creature deals damage to an opponent, tap target creature. That creature doesn't untap during its controller's untap step for as long as this creature remains tapped.",
				hits_opponent).targeting(TargetSpec.creature(), F._enemy_first))
		"Thalakos Mistfolk":
			shadow(c)
			# Role `self_bounce`: the fair AI's answer to an opposing spell
			# or ability aimed at it (the same shape as returning to hand).
			c.activated(ActivatedAbility.new("{U}", false,
				[F.Action.new(_mistfolk, "put this creature on top of its owner's library", null, true) \
					.with_ai_role(&"self_bounce")],
				"{U}: Put this creature on top of its owner's library."))
		"Thalakos Seer":
			shadow(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _seer,
				"When this creature leaves the battlefield, draw a card.", F._self_enter))
		# ------------------------------------------------------------ black
		"Dauthi Embrace":
			c.activated(ActivatedAbility.new("{B}{B}", false, [PumpEffect.new(0, 0, [Mtg.Keyword.SHADOW])],
				"{B}{B}: Target creature gains shadow until end of turn."))
		"Dauthi Ghoul":
			shadow(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _ghoul,
				"Whenever a creature with shadow dies, put a +1/+1 counter on this creature.", _shadow_died))
		"Dauthi Horror":
			shadow(c)
			c.static_ability(StaticAbility.new(_horror, "This creature can't be blocked by white creatures."))
		"Dauthi Mercenary":
			shadow(c)
			c.activated(ActivatedAbility.new("{1}{B}", false, [PumpEffect.new(1, 0).self_buff()],
				"{1}{B}: This creature gets +1/+0 until end of turn."))
		"Dauthi Mindripper":
			shadow(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _mindripper,
				"Whenever this creature attacks and isn't blocked, you may sacrifice it. If you do, defending player discards three cards.",
				F._self_enter))
		"Dauthi Slayer":
			shadow(c)
			if not c.keywords.has(Mtg.Keyword.MUST_ATTACK):
				c.with_keywords([Mtg.Keyword.MUST_ATTACK])
		# -------------------------------------------------------------- red
		"Shadowstorm":
			c.spell(DamageAllEffect.new(2, "each creature with shadow", has_shadow))
		"Wall of Diffusion":
			# The scaffold prints defender.
			c.static_ability(CombatState.blocks_shadow())
		# ------------------------------------------------------------ green
		"Heartwood Dryad":
			c.static_ability(CombatState.blocks_shadow())
		"Reality Anchor":
			c.spell(LoseAbilityEffect.new([Mtg.Keyword.SHADOW], "shadow"))
			c.spell(DrawEffect.new(1))
		# ------------------------------------------------------------- gold
		"Soltari Guerrillas":
			shadow(c)
			c.activated(ActivatedAbility.new("{0}", false, [GuerrillaRedirect.new()],
				"{0}: The next time this creature would deal combat damage to an opponent this turn, it deals that damage to target creature instead."))
		# ---------------------------------------------------- artifact, land
		"Phyrexian Splicer":
			for row in SPLICED:
				c.activated(_splice(int(row[0]), String(row[1])))
		"Maze of Shadows":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			var spec := TargetSpec.creature("target attacking creature with shadow", has_shadow) \
				.with_game_filter(_attacking).because(TargetSpec.WHY["attacking"])
			c.activated(ActivatedAbility.new("", true, [MazeOfShadows.new(spec).with_ai_role(&"fog_attacker")],
				"{T}: Untap target attacking creature with shadow. Prevent all combat damage that would be dealt to and dealt by that creature this turn."))
		_:
			return false
	return true


# =============================================================== shared ==

## Print shadow on [param c] once (the scaffolds predate the keyword).
static func shadow(c: CardData) -> void:
	if not c.keywords.has(Mtg.Keyword.SHADOW):
		c.with_keywords([Mtg.Keyword.SHADOW])


## "A creature with shadow": the LIVE keyword — a grant counts, a loss
## does not (CR 702.28, E1).
static func has_shadow(inst: CardInstance) -> bool:
	return inst != null and inst.is_creature() and inst.has_keyword(Mtg.Keyword.SHADOW)


## The seat a resolving ability acts for (CR 603.3a).
static func pid_of(g: MtgGame, s: CardInstance) -> int:
	return MC.pid_of(g, s)


## Trigger condition: [param s] dealt damage to a player who is not its
## controller ("deals damage to an opponent").
static func hits_opponent(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("source") == s and e.data.has("to_player") \
		and int(e.data.get("to_player", -1)) != s.controller_id and int(e.data.get("amount", 0)) > 0


## Trigger condition: [param s] dealt damage to its own controller (the
## other half of "deals damage to a player" — Soltari Visionary).
static func hits_controller(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("source") == s and e.data.has("to_player") \
		and int(e.data.get("to_player", -1)) == s.controller_id and int(e.data.get("amount", 0)) > 0


## "Whenever this creature attacks and isn't blocked, you may sacrifice
## it": the very object that triggered, still controlled by the trigger's
## controller (CR 701.17a: you sacrifice only what you control; a
## phased-out one can't be sacrificed, CR 702.26b), and that player says
## yes. True when it was sacrificed ("if you do").
static func sacrificed_by_choice(g: MtgGame, s: CardInstance, prompt: String, hint: bool) -> bool:
	var pid := pid_of(g, s)
	if not MC.same(g, s) or s.controller_id != pid:
		return false
	if not g.agents[pid].choose_yes_no(g, pid, prompt, hint):
		return false
	g.sacrifice_permanent(s)
	return s.zone != Mtg.Zone.BATTLEFIELD


# ========================================================== the cards ==

## Circle of Protection: Shadow — a creature permanent with shadow (CR
## 109.2: "creature" means a creature permanent), asked live.
static func _shadow_creature_source(source: CardInstance) -> bool:
	return source != null and source.zone == Mtg.Zone.BATTLEFIELD and has_shadow(source)


static func _first_strike_attacking(g: MtgGame, s: CardInstance) -> void:
	if g.combat.attackers.has(s.id) and not s.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE):
		s.cur_keywords.append(Mtg.Keyword.FIRST_STRIKE)


## Soltari Trooper: "it" is the attacker that triggered (CR 400.7).
static func _trooper(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not MC.same(g, s):
		return
	g.continuous.add_until_eot_pump(s.id, 1, 1)
	g.recalculate()


## Thalakos Dreamsower: tap the target; the lock lasts "for as long as this
## creature remains tapped" — from this resolution, while the Dreamsower is
## the same object and has not untapped since (its untap sequence). If it
## is already untapped (or gone) the duration has ended before it began and
## only the tap happens (CR 611.2b).
static func _dreamsower(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty():
		return
	var victim := g.find_instance(targets[0].instance_id)
	if not g.is_present(victim):
		return
	g.tap_permanent(victim)
	if not MC.same(g, s) or not s.tapped:
		return
	# What the untap step's "you may choose not to untap" heuristic reads
	# (MtgGame._is_sustaining): this creature holds something.
	g._rec(s, &"memory")
	s.memory["holding"] = victim.id
	g.continuous.add_floating_static(s, StaticAbility.new(
		_dream_lock.bind(victim.id, victim.layer_timestamp, s.layer_timestamp, s.untap_sequence),
		"Doesn't untap during its controller's untap step for as long as Thalakos Dreamsower remains tapped."),
		ContinuousEffects.Duration.INDEFINITE, -1, false, victim.id)
	g.recalculate()


static func _dream_lock(g: MtgGame, s: CardInstance, id: int, victim_stamp: int,
		stamp: int, untaps: int) -> void:
	if not g.is_present(s) or s.layer_timestamp != stamp or not s.tapped or s.untap_sequence != untaps:
		return
	var victim := g.find_instance(id)
	if g.is_present(victim) and victim.layer_timestamp == victim_stamp:
		victim.cur_skips_untap = true


static func _mistfolk(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if MC.live_source(g, s):
		g.return_permanent_to_library_top(s)


## Thalakos Seer: drawn by the player who controlled it as it left (CR
## 603.3a — the trigger's controller).
static func _seer(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(pid_of(g, s), 1)


## Dauthi Ghoul: the dead creature's last known information (CR 608.2h,
## 603.10a) — granted shadow counts, lost shadow does not, tokens count.
static func _shadow_died(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and (dead.last_types & Mtg.CardType.CREATURE) != 0 \
		and dead.had_keyword(Mtg.Keyword.SHADOW)


static func _ghoul(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if MC.same(g, s):
		g.add_counters(s, "+1/+1")


static func _horror(_g: MtgGame, s: CardInstance) -> void:
	s.cur_block_restrictions.append({"desc": "nonwhite creatures", "filter": _nonwhite})


static func _nonwhite(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.W) == 0


## Dauthi Mindripper: the defending player (CR 506.2) discards three of
## their choice. The hint sacrifices only into a hand of three or more
## (hand size is public).
static func _mindripper(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var foe := MC.defender(g)
	if not sacrificed_by_choice(g, s, "Sacrifice %s to make the defending player discard three cards?" % s.data.card_name,
			g.players[foe].hand.size() >= 3):
		return
	var count := mini(3, g.players[foe].hand.size())
	if count > 0:
		g.discard_cards(foe, g.agents[foe].choose_discard(g, foe, count))


static func _attacking(g: MtgGame, inst: CardInstance) -> bool:
	return g.combat.attackers.has(inst.id)


## Phyrexian Splicer, one row: "{2}, {T}, Choose <ability>: Until end of
## turn, target creature with the chosen ability loses it and another
## target creature gains it." Two targets, different objects (CR 115.3);
## each half is judged on its own as it resolves (CR 608.2b).
static func _splice(keyword: int, word: String) -> ActivatedAbility:
	var loses := LoseAbilityEffect.new([keyword], word,
		TargetSpec.creature("target creature with %s" % word, _has_keyword.bind(keyword)) \
			.because(TargetSpec.WHY["abilities"]))
	var gains := PumpEffect.new(0, 0, [keyword])
	gains.target_spec = TargetSpec.creature("another target creature") \
		.with_sibling_filter(_another, TargetSpec.WHY["cant_target"])
	return ActivatedAbility.new("{2}", true, [loses, gains],
		"{2}, {T}, Choose %s: Until end of turn, target creature with %s loses it and another target creature gains it." % [word, word])


static func _has_keyword(inst: CardInstance, keyword: int) -> bool:
	return inst.has_keyword(keyword)


static func _another(_g: MtgGame, _s: CardInstance, candidate: TargetRef, earlier: Array) -> bool:
	for ref in earlier:
		if ref != null and not ref.is_player and not candidate.is_player \
				and ref.instance_id == candidate.instance_id:
			return false
	return true


# ======================================================= effect classes ==

## Soltari Guerrillas: a one-shot REDIRECT of the damage replacement suite
## (engine/damage_replacements.gd): the next COMBAT damage event in which
## this creature (this object, CR 400.7) would deal damage to an opponent
## this turn is dealt to the target creature instead (CR 614.9). The
## redirected damage is still this creature's combat damage. A target gone
## by then leaves nowhere to send it, and the damage is dealt as usual (CR
## 614.6). A redirection is of the 1997 damage-prevention window's family
## (is_damage_prevention): made in the window, it moves the waiting packet.
class GuerrillaRedirect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()
		is_damage_prevention = true
		ai_role = &"combat_damage_to_creature"   # engine/ai/tempest_tactics.gd

	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or not MC.live_source(g, s):
			return
		var to := g.find_instance(t.instance_id)
		if not g.is_present(to):
			return
		var victims: Array = []
		for who in g.players.size():
			if who != pid:
				victims.append({"player": who})
		g.add_damage_effect({"kind": &"redirect", "one_shot": true, "combat_only": true,
			"controller": pid, "card": s.data.card_name, "source": s, "victims": victims,
			"to": TargetRef.card(to),
			"desc": "%s: its next combat damage to an opponent is dealt to %s instead" % [
				s.data.card_name, to.data.card_name]})
		g.log_line("%s: its next combat damage to an opponent goes to %s this turn" % [
			s.data.card_name, to.data.card_name])

	func describe() -> String:
		return "the next time this creature would deal combat damage to an opponent this turn, it deals that damage to %s instead" % target_spec.description


## Maze of Shadows: Maze of Ith's untap and both-ways combat fog (the
## floating combat-damage shield, drk/maze_of_ith.gd) on an attacking
## creature with shadow.
class MazeOfShadows extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var lost := g.find_instance(t.instance_id)
		if not g.is_present(lost):
			return
		g.untap_permanent(lost)
		g.continuous.add_until_eot_combat_prevention(lost.id, true, true)
		g.recalculate()

	func describe() -> String:
		return "untaps %s and prevents all combat damage dealt to and by it this turn" % target_spec.description
