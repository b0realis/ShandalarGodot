extends GameTest
## CARD SCRIPTS THAT DID NOT DO WHAT THEIR TEXT SAYS (the bug campaign c12,
## h3 — fixer F5b). Each test below failed on the code it was written
## against.
##
##  - h3-3: Winds of Rath, Extinction and Reign of Terror destroyed their
##    victims one after another inside a bracket, so the board recalculated
##    after each: a Mons's Goblin Raiders destroyed after its Goblin King
##    left as a 1/1 (Grim Feast paid 1 for it, not 2). One departure now,
##    as Wrath of God's.
##  - h3-4: Whimsy's rolled effects hit what Whimsy could never target — a
##    Fissure buried a Blue Ward's Bears, a Twiddle tapped Pincher Beetles.
##  - h3-7: Glyph of Doom cast before the blocks, on a Wall that then died
##    blocking a Craw Wurm, killed nothing.
##  - h3-9: the Runesword's curse, written from a damage watch, was not
##    journaled: an AI damage forecast left the real blocker cursed.
##  - h3-13: a second Lich arriving at -3 life "lost -3 life" — a gain the
##    bargain turned into three cards.
##  - h3-14: Sengir Vampire, Axelrod Gunnarson and Brine Hag matched the
##    damage source by id only, so a bounced-and-replayed creature counted
##    as its earlier self.
##  - h3-15: a Goblin Rock Sled stolen after attacking stayed tapped
##    through its new controller's untap step.


## Answers option questions by label (case-insensitive), else the hint.
class Scripted extends DecisionAgent:
	var options: Array = []

	func answer_option(_g: MtgGame, _p: int, _prompt: String,
			labels: Array[String], hint: int) -> int:
		if options.is_empty():
			return hint
		var want := String(options.pop_front()).to_lower()
		for i in labels.size():
			if labels[i].to_lower().contains(want):
				return i
		return hint


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)
	CardPacks.set_enabled("pack-9", false)


## Exactly the mana [param card]'s cost asks for (X as colorless).
func _fund(pid: int, card: CardInstance, x := 0) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)


func _cast(pid: int, card_name: String, targets: Array = [], x := 0) -> CardInstance:
	var card := give_hand(pid, card_name)
	_fund(pid, card, x)
	assert_ok(g.cast_spell(pid, card, targets, x))
	resolve_stack()
	return card


## P1's Goblin King and two Mons's Goblin Raiders (2/2 under the King),
## P0's Grim Feast: every goblin that dies pays P0 its toughness.
func _goblins_under_a_feast() -> Array[CardInstance]:
	put_battlefield(0, "Grim Feast")
	var out: Array[CardInstance] = [put_battlefield(1, "Goblin King"),
		put_battlefield(1, "Mons's Goblin Raiders"),
		put_battlefield(1, "Mons's Goblin Raiders")]
	assert_eq(out[1].cur_toughness, 2, "the King's +1/+1")
	advance_to_step(Mtg.Step.MAIN1)
	return out


# ------------------------------------------------------------ h3-3 ------

func test_winds_of_rath_takes_the_goblins_as_they_stood() -> void:
	var goblins := _goblins_under_a_feast()
	_cast(0, "Winds of Rath")
	for goblin in goblins:
		assert_eq(goblin.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 26, "2 + 2 + 2, as Wrath of God pays")


func test_extinction_takes_the_goblins_as_they_stood() -> void:
	var goblins := _goblins_under_a_feast()
	var seat := Scripted.new()
	seat.options = ["goblin"]
	g.set_agent(0, seat)
	_cast(0, "Extinction")
	for goblin in goblins:
		assert_eq(goblin.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 26, "2 + 2 + 2, as Wrath of God pays")


func test_reign_of_terror_takes_the_griffins_as_they_stood() -> void:
	put_battlefield(0, "Grim Feast")
	var zuberi := put_battlefield(1, "Zuberi, Golden Feather")
	var griffin := put_battlefield(1, "Teremko Griffin")
	assert_eq(griffin.cur_toughness, 3, "Zuberi's +1/+1 to other Griffins")
	advance_to_step(Mtg.Step.MAIN1)
	var seat := Scripted.new()
	seat.options = ["white"]
	g.set_agent(0, seat)
	_cast(0, "Reign of Terror")
	assert_eq(zuberi.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(griffin.zone, Mtg.Zone.GRAVEYARD)
	# 20 - 2 x 2 for the two that died, + 3 + 3 from the Feast.
	assert_eq(g.players[0].life, 22, "the Griffin died a 3/3")


# ------------------------------------------------------------ h3-4 ------

func _whimsy() -> CardInstance:
	return give_hand(0, "Whimsy")


func _blue_warded_bears() -> CardInstance:
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Blue Ward", [TargetRef.card(bears)])
	assert_true((bears.cur_protection & Mtg.ManaColor.U) != 0, "protection from blue")
	return bears


func test_whimsy_fissure_never_rolls_a_creature_protected_from_blue() -> void:
	var bears := _blue_warded_bears()
	RandomEffectTable.play(g, _whimsy(), 0, 8)   # Fissure
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "Whimsy can't target it")
	assert_true(g.log_lines[-1].contains("Fissure fizzles"), g.log_lines[-1])


func test_whimsy_twiddle_never_rolls_a_shrouded_creature() -> void:
	var beetles := put_battlefield(1, "Pincher Beetles")
	assert_true(beetles.cur_shroud)
	advance_to_step(Mtg.Step.MAIN1)
	RandomEffectTable.play(g, _whimsy(), 0, 2)   # Twiddle to tap
	assert_false(beetles.tapped, "shroud: nothing may target it")
	assert_true(g.log_lines[-1].contains("Twiddle fizzles"), g.log_lines[-1])


func test_whimsy_aladdins_ring_rolls_only_players_past_a_warded_creature() -> void:
	var bears := _blue_warded_bears()
	var whimsy := _whimsy()
	var dealt := 0
	for _n in 12:
		RandomEffectTable.play(g, whimsy, 0, 3)   # Aladdin's Ring
		for p in g.players:
			dealt += 20 - p.life
			p.life = 20   # setup: keep both seats in the game
	assert_eq(bears.damage, 0, "never the warded Bears")
	assert_eq(dealt, 12 * 4, "every Ring found a player")


# ------------------------------------------------------------ h3-7 ------

## P0's Craw Wurm attacks; P1 casts Glyph of Doom on Wall of Wood in the
## declare-attackers step, BEFORE the blocks; the Wall blocks the Wurm.
func _glyph_before_the_blocks() -> Array[CardInstance]:
	var wurm := put_battlefield(0, "Craw Wurm")
	var wall := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	var glyph := give_hand(1, "Glyph of Doom")
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(wall)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: wurm.id}))
	return [wurm, wall]


func test_glyph_of_doom_cast_before_the_blocks_outlives_the_dead_wall() -> void:
	var pair := _glyph_before_the_blocks()
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(pair[1].zone, Mtg.Zone.GRAVEYARD, "the 0/3 died to the 6/4")
	assert_eq(pair[0].zone, Mtg.Zone.GRAVEYARD,
		"it was blocked by that creature this turn")


func test_glyph_of_doom_outlives_a_wall_bounced_after_blocking() -> void:
	var pair := _glyph_before_the_blocks()
	g.return_to_hand(pair[1])
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(pair[0].zone, Mtg.Zone.GRAVEYARD)


func test_glyph_of_doom_spares_a_blocked_creature_that_came_back() -> void:
	var pair := _glyph_before_the_blocks()
	g.return_to_hand(pair[0])
	g.put_from_hand_into_play(pair[0], 0)   # a new object (CR 400.7)
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(pair[0].zone, Mtg.Zone.BATTLEFIELD, "it was never blocked")


# ------------------------------------------------------------ h3-9 ------

func test_runesword_forecast_leaves_no_curse_behind() -> void:
	var sword := put_battlefield(0, "Runesword")
	var giant := put_battlefield(0, "Hill Giant")
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, sword, 0, [TargetRef.card(giant)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {skeletons.id: giant.id}))
	var forecast := g.forecast_damage(true)
	assert_false(bool(forecast["alive"].get(skeletons.id, false)),
		"the forecast saw the cut")
	assert_false(skeletons.regeneration_banned_this_turn,
		"the forecast's curse was unwound")
	assert_false(skeletons.exile_instead_of_dying)
	assert_eq(skeletons.damage, 0)


# ----------------------------------------------------------- h3-13 ------

func test_a_second_lich_at_negative_life_draws_nothing() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Lich")
	assert_eq(g.players[0].life, 0)
	g.adjust_life(0, -3)
	assert_eq(g.players[0].life, -3)
	var hand := g.players[0].hand.size()
	put_battlefield(0, "Lich")
	assert_eq(g.players[0].life, -3, "a negative loss is no loss (CR 107.1b)")
	assert_eq(g.players[0].hand.size(), hand, "no gain, so no cards")
	assert_false(g.game_over)


# ----------------------------------------------------------- h3-14 ------

## [param biter] deals 2 to [param victim]; when [param replay] it is then
## bounced and played again — a new object (CR 400.7).
func _bite(biter: CardInstance, victim: CardInstance, replay: bool) -> void:
	advance_to_step(Mtg.Step.MAIN1)
	g.deal_damage(biter, TargetRef.card(victim), 2)
	assert_eq(victim.damage, 2)
	if replay:
		g.return_to_hand(biter)
		g.put_from_hand_into_play(biter, biter.owner_id)


func test_sengir_vampire_is_not_paid_for_its_earlier_self() -> void:
	var vampire := put_battlefield(0, "Sengir Vampire")
	var giant := put_battlefield(1, "Hill Giant")
	_bite(vampire, giant, true)
	_cast(0, "Lightning Bolt", [TargetRef.card(giant)])
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(int(vampire.counters.get("+1/+1", 0)), 0)


func test_sengir_vampire_is_paid_for_its_own_bite() -> void:
	var vampire := put_battlefield(0, "Sengir Vampire")
	var giant := put_battlefield(1, "Hill Giant")
	_bite(vampire, giant, false)
	_cast(0, "Lightning Bolt", [TargetRef.card(giant)])
	assert_eq(int(vampire.counters.get("+1/+1", 0)), 1)


func test_axelrod_is_not_paid_for_its_earlier_self() -> void:
	var axelrod := put_battlefield(0, "Axelrod Gunnarson")
	var giant := put_battlefield(1, "Hill Giant")
	_bite(axelrod, giant, true)
	_cast(0, "Lightning Bolt", [TargetRef.card(giant)])
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20, "no life for a creature its earlier self bit")
	assert_eq(g.players[1].life, 20)


func test_brine_hag_spares_a_biter_that_came_back() -> void:
	var hag := put_battlefield(1, "Brine Hag")
	var bears := put_battlefield(0, "Grizzly Bears")
	var ogre := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	g.deal_damage(bears, TargetRef.card(hag), 1)
	g.return_to_hand(bears)
	g.put_from_hand_into_play(bears, 0)
	g.deal_damage(ogre, TargetRef.card(hag), 1)   # the second point: lethal
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(hag.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.cur_power, 2, "a new object: never bit the Hag")
	assert_eq(ogre.cur_power, 0, "the biter that stayed is cursed")
	assert_eq(ogre.cur_toughness, 2)


# ----------------------------------------------------------- h3-15 ------

func test_goblin_rock_sled_stolen_after_attacking_untaps_for_its_thief() -> void:
	var sled := put_battlefield(0, "Goblin Rock Sled")
	put_battlefield(1, "Mountain")
	run_combat([sled.id])
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_true(sled.tapped)
	g.change_control(sled, 1)
	assert_eq(sled.controller_id, 1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_false(sled.tapped, "it never attacked during the thief's last turn")
