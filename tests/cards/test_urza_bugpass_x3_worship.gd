extends GameTest
## 0.60.19 bug pass, h6-1 — a LIFE FLOOR limits the LIFE LOST, not the
## damage. Worship and Ali from Cairo: "damage that would reduce your life
## total to less than 1 reduces it to 1 instead". Gatherer 2004-10-04 on
## Worship: "It doesn't prevent damage; it changes the result of the damage
## dealt to you" — so the damage is still DEALT, and "the damage dealt this
## way" (Corrupt), "whenever ... deals damage to a player" (Order of
## Yawgmoth) and "was dealt damage this turn" (Antagonism) all see it in
## full. Forge models both cards the same way, as a replacement of the LIFE
## REDUCTION (`res/cardsfolder/w/worship.txt`, `a/ali_from_cairo.txt`,
## `Event$ LifeReduced | IsDamage$ True`, revision b09a3d3f) — not of the
## damage, so it is no line of the CR 616.1 damage-order question either.
##
## The engine used to run the floor as a PREVENTION gate: what it stopped
## was never dealt.

const PRESETS := ["modern_mana_burn", "fifth"]


## Records the CR 616.1 questions it is asked; answers with the hint.
class Orderer extends DecisionAgent:
	var asked: Array[String] = []
	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			_options: Array[String], hint: int) -> int:
		asked.append(prompt)
		return hint


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


func _fresh(preset: String) -> void:
	super.before_each()
	g.rules.set_preset(preset)
	advance_to_step(Mtg.Step.MAIN1)


## A synthetic ledger: every LIFE_LOST amount it hears, without a trigger.
static func _ledger(losses: Array) -> CardData:
	var c := CardData.new("Test Ledger", "{0}", Mtg.CardType.ARTIFACT)
	return c.triggered(TriggeredAbility.new(Mtg.EventType.LIFE_LOST,
		func(_g: MtgGame, _s: CardInstance, _e: GameEvent) -> void: pass,
		"Records the life lost.",
		func(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
			losses.append(int(e.data.get("amount", 0)))
			return false))


func _worship_seat(pid: int, life: int) -> void:
	put_battlefield(pid, "Worship")
	put_battlefield(pid, "Grizzly Bears")
	g.players[pid].life = life


# ------------------------------------------------- the damage is dealt --

func test_corrupt_into_worship_gains_the_full_damage() -> void:
	_worship_seat(1, 2)
	for _i in 4: put_battlefield(0, "Swamp")
	var corrupt := give_hand(0, "Corrupt")
	add_mana(0, Mtg.ManaColor.B, 6)
	assert_ok(g.cast_spell(0, corrupt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 1, "Worship leaves 1")
	assert_eq(g.players[0].life, 24, "Corrupt dealt 4 damage, so its caster gains 4")


func test_order_of_yawgmoth_still_makes_a_worship_player_at_one_discard() -> void:
	_worship_seat(1, 1)
	give_hand(1, "Forest")
	var order := put_battlefield(0, "Order of Yawgmoth")
	g.deal_damage(order, TargetRef.player(1), 2, true)
	resolve_stack()
	assert_eq(g.players[1].life, 1)
	assert_eq(g.players[1].hand.size(), 0, "2 damage was dealt to the player: discard")


func test_antagonism_sees_damage_dealt_to_a_worship_player() -> void:
	put_battlefield(0, "Antagonism")
	_worship_seat(1, 1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 1)
	assert_eq(g.players[1].damage_taken_this_turn, 3, "the Bolt's 3 damage was dealt")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "an opponent was dealt damage this turn: no Antagonism damage")


func test_ali_from_cairo_deals_the_damage_and_limits_the_loss_in_both_rules() -> void:
	for preset in PRESETS:
		_fresh(preset)
		put_battlefield(0, "Ali from Cairo")
		g.players[0].life = 2
		var losses: Array = []
		put_synthetic(1, _ledger(losses))
		var giant := put_battlefield(1, "Hill Giant")
		var dealt := g.deal_damage(giant, TargetRef.player(0), 3)
		assert_eq(dealt, 3, "%s: the damage is dealt in full" % preset)
		assert_eq(g.players[0].damage_taken_this_turn, 3, preset)
		assert_eq(int(g.damage_dealt_this_turn.get(giant.id, 0)), 3, preset)
		assert_true(giant.damaged_players_this_turn.has(0), preset)
		assert_eq(g.players[0].life, 1, "%s: Ali holds the life total at 1" % preset)
		assert_eq(losses, [1], "%s: only the 1 life really lost is announced" % preset)
		assert_false(g.game_over, preset)


func test_a_floor_that_takes_nothing_announces_no_life_loss() -> void:
	_worship_seat(0, 1)
	var losses: Array = []
	put_synthetic(1, _ledger(losses))
	var giant := put_battlefield(1, "Hill Giant")
	assert_eq(g.deal_damage(giant, TargetRef.player(0), 3), 3)
	assert_eq(g.players[0].life, 1)
	assert_eq(losses, [], "no life was lost")


func test_worship_still_lets_damage_kill_without_a_creature() -> void:
	put_battlefield(0, "Worship")
	g.players[0].life = 2
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(giant, TargetRef.player(0), 3)
	assert_true(g.game_over, "no creature, no floor")


# ------------------------------------ the damage-order question and forecasts --

# Worship and Forethought Amulet both looked at the Bolt, so the damaged
# seat was asked which applies first — a question with one answer, since
# the floor changes no damage. Only the Amulet modifies the damage event.
func test_the_floor_is_no_line_of_the_damage_order_question() -> void:
	_worship_seat(0, 2)
	put_battlefield(0, "Forethought Amulet")
	var orderer := Orderer.new()
	g.set_agent(0, orderer)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(orderer.asked.size(), 0, "one effect on the damage: nobody is asked")
	assert_eq(g.players[0].damage_taken_this_turn, 2, "the Amulet made it 2")
	assert_eq(g.players[0].life, 1, "and Worship kept the life total at 1")


func test_the_forecasts_price_the_life_a_floor_lets_go() -> void:
	_worship_seat(0, 2)
	var bolt := give_hand(1, "Lightning Bolt")
	var tactics := preload("res://engine/ai/ice_age_tactics.gd")
	assert_eq(tactics.damage_through(g, bolt, TargetRef.player(0), 3), 1,
		"the AI's face-damage estimate costs the Worship player 1 life")
	var predicted := g.predict_damage(bolt, TargetRef.player(0), 3, false, 1)
	assert_eq(int(predicted["dealt"]), 1, "life lost")
	assert_eq(int(predicted["elsewhere"]), 0, "nothing went anywhere else")
	assert_eq(int(predicted["life"]), 1)
	assert_eq(g.players[0].life, 2, "a prediction changes nothing")
