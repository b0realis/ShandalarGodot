extends GameTest
## THE COMPUTER ORDERS ITS OWN DAMAGE EFFECTS (the owner's ruling of
## 2026-10-12, campaign 2026-10-12 f-order; [member
## AiProfile.forecasts_tactics]).
##
## Under the modern rules the affected player — or the affected creature's
## controller — chooses which replacement or prevention effect applies
## first (CR 616.1). The computer used to answer that question with the
## engine's hint, index 0: the fixed order, which puts what helps the
## victim first and what hurts it last. That is the WRONG order whenever a
## cap meets an increase — a Lightning Bolt into a Forethought Amulet ("3
## or more ... deals 2 instead") and a Furnace of Rath ("double that
## damage") deals 4 with the Amulet first and 2 with the Furnace first.
##
## AiPlayer.answer_option now recognises the question when it is its own
## and takes the first pick whose best continuation lands the least damage
## on it (MtgGame.damage_order_outcomes, a look-ahead over the engine's
## own walk; ties keep the hint). The board is public, so fair play is not
## at stake; the hidden-hand permutation below pins that the look-ahead
## reads nothing else. Gate off: the hint, exactly as before.

const PACKS := ["pack-9"]
const MODERN := ["modern_mana_burn", "modern"]


func before_each() -> void:
	for p in PACKS: CardPacks.set_enabled(p, true)
	CardRegistry.ensure_loaded()
	super.before_each()


func after_each() -> void:
	g = null
	for p in PACKS: CardPacks.set_enabled(p, false)


func _fresh(preset: String, on := true, profile: AiProfile = null) -> AiPlayer:
	super.before_each()
	g.rules.set_preset(preset)
	var p := profile if profile != null else AiProfile.wizard()
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	advance_to_step(Mtg.Step.MAIN1)
	return ai


## P1, with a Furnace of Rath, aims a Lightning Bolt at [param target].
func _bolt(target: TargetRef) -> void:
	put_battlefield(1, "Furnace of Rath")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [target]))
	resolve_stack()


## The answer P0 gave the ordering question, -1 when it was not asked.
func _order_answer() -> int:
	for choice in g.choice_log:
		if choice.pid == 0 and choice.prompt.begins_with("Which applies first"):
			return int(choice.answer)
	return -1


# ===================================================== the player branch ==

func test_the_computer_takes_2_from_the_bolt_not_4() -> void:
	for preset in MODERN:
		for profile in [AiProfile.wizard(), AiProfile.sorcerer(), AiProfile.magician(),
				AiProfile.apprentice()]:
			_fresh(preset, true, profile)
			put_battlefield(0, "Forethought Amulet")
			_bolt(TargetRef.player(0))
			assert_eq(_order_answer(), 1, "%s %s: the Furnace first" % [preset, profile.profile_name])
			assert_eq(g.players[0].life, 18,
				"%s %s: doubled to 6, then capped at 2" % [preset, profile.profile_name])


func test_gate_off_the_hint_is_kept() -> void:
	_fresh("modern_mana_burn", false)
	put_battlefield(0, "Forethought Amulet")
	_bolt(TargetRef.player(0))
	assert_eq(_order_answer(), 0, "the fixed order's first: the Amulet")
	assert_eq(g.players[0].life, 16, "capped at 2, then doubled: 4")


func test_under_the_1997_rules_the_computer_is_not_asked() -> void:
	for on in [true, false]:
		_fresh("fifth", on)
		put_battlefield(0, "Forethought Amulet")
		_bolt(TargetRef.player(0))
		assert_eq(_order_answer(), -1, "gate %s: nobody is asked" % on)
		assert_eq(g.players[0].life, 16, "gate %s: the fixed order" % on)


func test_a_tie_keeps_the_hint() -> void:
	# A Circle of Protection: Red that names the Bolt and the Amulet: either
	# first lands nothing (the Circle prevents all of it, before or after
	# the cap), so the hint — the fixed order's first — is kept.
	_fresh("modern_mana_burn")
	put_battlefield(0, "Forethought Amulet")
	g.players[0].prevention_shield_filters.append({"desc": "Test circle",
		"filter": func(_source: CardInstance) -> bool: return true})
	_bolt(TargetRef.player(0))
	assert_eq(g.players[0].life, 20)
	assert_eq(_order_answer(), 0, "a tie at 0 keeps the hint")


# =================================================== the creature branch ==

## A Craw Wurm (6/4) of P0's under a test cap: 3 or more damage to it
## becomes 2 — the Amulet's shape, on a creature.
func _capped_wurm() -> CardInstance:
	var wurm := put_battlefield(0, "Craw Wurm")
	assert_true(g.add_damage_effect({"desc": "Test cap", "kind": &"replace",
		"victims": [wurm],
		"filter": func(_game: MtgGame, packet: DamagePacket) -> bool:
			return packet.remaining() >= 3,
		"apply": func(game: MtgGame, packet: DamagePacket) -> int:
			game._rec(packet, &"amount")
			packet.amount -= packet.remaining() - 2
			return -1}) >= 0)
	return wurm


func test_the_computer_orders_its_creature_s_damage_too() -> void:
	for preset in MODERN:
		_fresh(preset)
		var wurm := _capped_wurm()
		_bolt(TargetRef.card(wurm))
		assert_eq(_order_answer(), 1, "%s: the Furnace first" % preset)
		assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "%s: the Wurm lives" % preset)
		assert_eq(wurm.damage, 2, "%s: doubled to 6, then capped at 2" % preset)


func test_gate_off_the_creature_takes_the_hint() -> void:
	_fresh("modern_mana_burn", false)
	var wurm := _capped_wurm()
	_bolt(TargetRef.card(wurm))
	assert_eq(_order_answer(), 0)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "capped at 2, doubled to 4: lethal")


# ================================================== fair information ==

## THE HIDDEN-HAND PERMUTATION (docs/fair-play.md): the opponent's hand and
## library are hidden, and whatever they hold the computer's answer is the
## same — the look-ahead runs the damage walk and nothing else.
func test_the_opponent_s_hidden_cards_do_not_move_the_pick() -> void:
	var hands := [[], ["Giant Growth", "Counterspell"],
		["Fireball", "Lightning Bolt", "Shock", "Healing Salve"]]
	var answers := []
	var outcomes := []
	for hand in hands:
		_fresh("modern_mana_burn")
		for card_name in hand:
			give_hand(1, card_name)
		g.players[1].library.reverse()
		put_battlefield(0, "Forethought Amulet")
		_bolt(TargetRef.player(0))
		answers.append(_order_answer())
		outcomes.append(g.players[0].life)
	assert_eq(answers, [1, 1, 1], "the same pick whatever they hold")
	assert_eq(outcomes, [18, 18, 18])
