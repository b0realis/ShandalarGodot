extends RefCounted
## Exodus (_shadow, Pack 9). Shadow (CR 702.28): creatures that can block or be blocked only by creatures with shadow, and the cards that grant or answer it.
##
## Batch B1, over the Pack 9 E1 shadow keyword and the Tempest shadow
## module's helpers (cards/sets/tmp/_shadow.gd):
## - Dauthi Cutthroat: "target creature with shadow" is the LIVE keyword
##   ([code]S.has_shadow[/code]) — a creature that gained shadow this turn
##   is a legal target, one that lost it is not.
## - Dauthi Jackal: "target blocking creature" (any player's), the Jackal
##   sacrificed as the cost.
## - Dauthi Warlord: a characteristic-defining power (CR 604.3) that counts
##   creatures WITH SHADOW, so it is applied after the whole of layer 6
##   (Pack 9 E5: [code]setting_base_pt().reading_abilities()[/code]) and
##   sees a shadow granted this turn; it is also its value in every zone
##   ([member CardData.characteristic_definition]).
## - Soltari Visionary: "that player" is the damaged player. A trigger's
##   target is named as it goes on the stack (CR 603.3d), before its
##   resolution context exists, so the ability is written as two triggers
##   with complementary conditions — damage to an opponent (an enchantment
##   an opponent controls) and to its own controller (one they control).
##   Exactly one of them triggers for each player dealt damage.
## - Thalakos Drifters / Thalakos Scout: a discard COST
##   (ActivatedAbility.with_discard_cost) — the card goes as the ability is
##   activated.
## tests/cards/test_pack_9_B1_*.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const MC := preload("res://cards/sets/mir/_combat.gd")
const S := preload("res://cards/sets/tmp/_shadow.gd")

const VISIONARY_TEXT := "Whenever this creature deals damage to a player, destroy target enchantment that player controls."


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Dauthi Cutthroat":
			S.shadow(c)
			c.activated(ActivatedAbility.new("{1}{B}", true,
				[DestroyEffect.new(TargetSpec.creature("target creature with shadow", S.has_shadow) \
					.because(TargetSpec.WHY["abilities"]))],
				"{1}{B}, {T}: Destroy target creature with shadow."))
		"Dauthi Jackal":
			S.shadow(c)
			c.activated(ActivatedAbility.new("{B}{B}", false,
				[DestroyEffect.new(TargetSpec.creature("target blocking creature").with_game_filter(_blocking) \
					.because(TargetSpec.WHY["blocking"]))],
				"{B}{B}, Sacrifice this creature: Destroy target blocking creature.").with_sacrifice_cost())
		"Dauthi Warlord":
			S.shadow(c)
			c.static_ability(StaticAbility.new(_warlord_power,
				"Dauthi Warlord's power is equal to the number of creatures on the battlefield with shadow.") \
				.setting_base_pt().reading_abilities())
			c.characteristic_definition = _warlord_power
		"Soltari Visionary":
			S.shadow(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _visionary, VISIONARY_TEXT,
				S.hits_opponent).targeting(_enchantment_spec(_opponents), Callable(),
				"Select an enchantment that player controls."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _visionary, VISIONARY_TEXT,
				S.hits_controller).targeting(_enchantment_spec(_yours), Callable(),
				"Select an enchantment that player controls."))
		"Thalakos Drifters":
			# Role `self_keyword` (Manta Riders' reading), the discard priced
			# as the cost it is.
			c.activated(ActivatedAbility.new("", false,
				[PumpEffect.new(0, 0, [Mtg.Keyword.SHADOW]).self_buff() \
					.with_ai_role(&"self_keyword", {"keyword": Mtg.Keyword.SHADOW})],
				"Discard a card: This creature gains shadow until end of turn.").with_discard_cost(1))
		"Thalakos Scout":
			S.shadow(c)
			# Role `self_bounce`: the fair AI's answer to an opposing spell
			# or ability aimed at it.
			c.activated(ActivatedAbility.new("", false,
				[F.Action.new(_scout, "return this creature to its owner's hand", null, true) \
					.with_ai_role(&"self_bounce")],
				"Discard a card: Return this creature to its owner's hand.").with_discard_cost(1))
		_:
			return false
	return true


static func _blocking(g: MtgGame, inst: CardInstance) -> bool:
	return F._blocking(g, inst)


## Dauthi Warlord (E5's contract): every creature on the battlefield with
## shadow, itself included, whoever controls it.
static func _warlord_power(game: MtgGame, source: CardInstance) -> void:
	var n := 0
	for inst in game.all_battlefield():
		if inst.is_creature() and not inst.phased_out and inst.has_keyword(Mtg.Keyword.SHADOW):
			n += 1
	source.cur_power = n


static func _enchantment_spec(owner_filter: Callable) -> TargetSpec:
	return TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment that player controls", _enchantment) \
		.with_source_filter(owner_filter)


static func _enchantment(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ENCHANTMENT)


## "That player" = an opponent of the trigger's controller (two seats).
static func _opponents(g: MtgGame, s: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id != g.controller_acting_for(s)


## "That player" = the trigger's own controller (damage it dealt to them).
static func _yours(g: MtgGame, s: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == g.controller_acting_for(s)


## Soltari Visionary: the destruction is an effect of the trigger, so it
## happens even if the Visionary has left by then (CR 603.6, 608.2h).
static func _visionary(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty():
		return
	var victim := g.find_instance(targets[0].instance_id)
	if g.is_present(victim):
		g.destroy(victim)


static func _scout(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if MC.live_source(g, s):
		g.return_to_hand(s)
