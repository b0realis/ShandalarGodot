extends RefCounted
## Stronghold (_buyback, Pack 9). Buyback (CR 702.27): spells that return to their owner's hand when the buyback cost was paid.
##
## Buyback is a PAYMENT ROW (CardData.with_buyback, engine package E2) —
## see cards/sets/tmp/_buyback.gd. A mana buyback, a coloured one
## ({2}{U}, {2}{B}{B}) or "Sacrifice a land" (an object cost validated with
## the rest of the cast, paid as it is cast, CR 601.2h). The casting AI
## reads the row (AiPlayer._buyback_row); a land sacrifice keeps the pilot
## at its land floor. Tests: tests/cards/test_pack_9_B2_buyback.gd,
## test_pack_9_B2_buyback_sth_exo.gd, test_pack_9_B2_ai.gd.
const F := preload("res://cards/sets/fem/_rules.gd")
const OC := preload("res://engine/additional_object_costs.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Change of Heart":
			c.spell(F.Action.new(_cant_attack, "target creature can't attack this turn",
				TargetSpec.creature()).with_ai_role(&"cant_attack_this_turn"))
			c.with_buyback({"mana": "{3}"})
		# ------------------------------------------------------------- blue
		"Mind Games":
			c.spell(TapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target artifact, creature, or land", _artifact_creature_or_land)))
			c.with_buyback({"mana": "{2}{U}"})
		# ------------------------------------------------------------ black
		"Brush with Death":
			var drain := GainLifeEffect.new(-2)
			drain.target_spec = TargetSpec.opponent()
			c.spell(drain)
			c.spell(GainLifeEffect.new(2))
			c.with_buyback({"mana": "{2}{B}{B}"})
		"Lab Rats":
			c.spell(CreateTokenEffect.new("Rat", 1, 1, Mtg.ManaColor.B, "rat"))
			c.with_buyback({"mana": "{4}"})
		"Mind Peel":
			c.spell(F.Action.new(_discard_one, "target player discards a card (their choice)",
				TargetSpec.player()).with_ai_role(&"discard", {"count": 1}))
			c.with_buyback({"mana": "{2}{B}{B}"})
		# -------------------------------------------------------------- red
		"Fanning the Flames":
			# X is announced as usual; the buyback row costs {X}{R}{R}{3}.
			c.spell(DamageEffect.new(0).x_damage().any_target())
			c.with_buyback({"mana": "{3}"})
		"Seething Anger":
			c.spell(PumpEffect.new(3, 0))
			c.with_buyback({"mana": "{3}"})
		# ------------------------------------------------------------ green
		"Constant Mists":
			c.spell(PreventCombatDamageEffect.new())
			c.with_buyback({"object_costs": [OC.sacrificing("a land", _land)], "text": "Sacrifice a land"})
		"Verdant Touch":
			c.spell(F.Action.new(_verdant_touch, "target land becomes a 2/2 creature that's still a land",
				TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land), true) \
				.with_ai_role(&"animate_land", {"power": 2, "toughness": 2, "indefinite": true}))
			c.with_buyback({"mana": "{3}"})
		_: return false
	return true


static func _land(i: CardInstance) -> bool: return i.is_land()
static func _artifact_creature_or_land(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) or i.is_creature() or i.is_land()


## "Target creature can't attack this turn." A creature already attacking
## stays in combat (the Change of Heart ruling): the flag only answers the
## declaration, and the untap step clears it.
static func _cant_attack(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id) if t != null else null
	if i == null or i.zone != Mtg.Zone.BATTLEFIELD: return
	g._rec(i, &"cant_attack_this_turn")
	i.cant_attack_this_turn = true
	g.log_line("%s can't attack this turn" % i.data.card_name)


## "Target player discards a card" — THEIR choice (Disrupting Scepter).
static func _discard_one(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if t == null or not t.is_player: return
	var who := t.player_id
	var hand := g.players[who].hand
	if hand.is_empty(): return
	var picked := g.agents[who].choose_discard(g, who, 1)
	var card: CardInstance = picked[0] if not picked.is_empty() and hand.has(picked[0]) else hand[0]
	g.discard_cards(who, [card])


## "Target land becomes a 2/2 creature that's still a land. (This effect
## lasts indefinitely.)" Layer 4 adds the type and layer 7b sets the base
## P/T (the animation registry, CR 611.2b); a land that leaves forgets it
## (CR 400.7). It keeps its other types, abilities and colour.
static func _verdant_touch(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var land := g.find_instance(t.instance_id) if t != null else null
	if land == null or land.zone != Mtg.Zone.BATTLEFIELD: return
	g.continuous.add_until_eot_animation(land.id, Mtg.CardType.CREATURE, 2, 2, [], false,
		ContinuousEffects.Duration.INDEFINITE)
	g.recalculate()
	g.log_line("%s becomes a 2/2 creature" % land.data.card_name)
