extends GameTest
## Pack 9 (the Tempest block), batch B5: the Tempest triggered permanents in
## cards/sets/tmp/_triggers.gd — real stack triggers, intervening-"if"
## rechecks (CR 603.4), last known information for a departed source or
## victim (CR 603.6 / 608.2h), whose choice each "may"/"unless" is, and the
## coin flips driven through the seeded game RNG.

const CLAIMED := ["Ancient Runes", "Angelic Protector", "Avenging Angel", "Bellowing Fiend",
	"Chaotic Goo", "Cloudchaser Eagle", "Commander Greven il-Vec", "Death Pits of Rath",
	"Dirtcowl Wurm", "Field of Souls", "Fugitive Druid", "Havoc", "Insight", "Jackal Pup",
	"Kezzerdrix", "Legacy's Allure", "Magmasaur", "Mongrel Pack", "Orim's Prayer",
	"Rathi Dragon", "Recycle", "Sarcomancy", "Segmented Wurm", "Servant of Volrath",
	"Shocker", "Spirit Mirror", "Staunch Defenders", "Unstable Shapeshifter",
	"Verdant Force", "Warmth", "Wild Wurm"]

## A seat whose answers a test scripts: yes/no (-1 follows the hint) and
## card names to prefer (else the first, ranked candidate).
class Seat extends DecisionAgent:
	var yes := -1
	var prefer: Array = []
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


## Pass until [param pid]'s upkeep of a LATER turn, its triggers waiting.
func _to_upkeep(pid: int) -> void:
	var start := g.turn_number
	var guard := 0
	while not g.game_over and guard < 800 and not (g.turn_number > start
			and g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP):
		_advance_once()
		guard += 1
	assert_lt(guard, 800, "never reached the upkeep")


func _counter(i: CardInstance, kind: String) -> int:
	return int(i.counters.get(kind, 0))


func _named(pid: int, card_name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.data.card_name == card_name: out.append(i)
	return out


## Seed the game RNG so the NEXT coin flip is won (or lost): MtgGame.flip_coin
## wins on an even randi().
func _seed_flip(win: bool) -> void:
	for n in range(1, 500):
		var probe := RandomNumberGenerator.new()
		probe.seed = n
		if ((probe.randi() % 2) == 0) == win:
			g.rng.seed = n
			return
	fail_test("no seed found")


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_false(c.triggered_abilities.is_empty(), "%s has its trigger" % card_name)


# ------------------------------------------------------------- Ancient Runes --

func test_ancient_runes_burns_each_player_for_their_own_artifacts() -> void:
	put_battlefield(0, "Ancient Runes")
	put_battlefield(0, "Ornithopter")
	put_battlefield(1, "Ornithopter")
	put_battlefield(1, "Jayemdae Tome")
	_to_upkeep(1)
	assert_eq(g.stack.size(), 1, "each player's upkeep")
	resolve_stack()
	assert_eq(g.players[1].life, 18, "two artifacts")
	assert_eq(g.players[0].life, 20)
	_to_upkeep(0)
	resolve_stack()
	assert_eq(g.players[0].life, 19, "its controller's own artifact counts too")


func test_ancient_runes_spares_a_player_with_no_artifacts() -> void:
	put_battlefield(0, "Ancient Runes")
	_to_upkeep(1)
	resolve_stack()
	assert_eq(g.players[1].life, 20)


# --------------------------------------------------------- Angelic Protector --

func test_angelic_protector_toughens_when_targeted_and_survives_the_bolt() -> void:
	var angel := put_battlefield(0, "Angelic Protector")
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))
	g.pass_priority(0)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(angel)]))
	assert_eq(g.stack.size(), 2, "the trigger waits above the Bolt (CR 601.2c)")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq([angel.cur_power, angel.cur_toughness], [2, 5])
	assert_eq(angel.damage, 3)
	advance_to_next_turn()
	assert_eq(angel.cur_toughness, 2, "until end of turn")


func test_angelic_protector_ignores_untargeted_damage() -> void:
	var angel := put_battlefield(0, "Angelic Protector")
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(giant, TargetRef.card(angel), 1)
	assert_true(g.stack.is_empty())
	assert_eq(angel.cur_toughness, 2)


# ------------------------------------------------------------ Avenging Angel --

func test_avenging_angel_may_go_on_top_of_its_owners_library() -> void:
	var angel := put_battlefield(0, "Avenging Angel")
	me.yes = 1
	g.destroy(angel)
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), angel, "on top")
	var second := put_battlefield(0, "Avenging Angel")
	me.yes = 0
	g.destroy(second)
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "declined")


func test_avenging_angel_stolen_asks_its_controller_and_goes_to_its_owner() -> void:
	var angel := put_battlefield(0, "Avenging Angel")
	g.change_control(angel, 1)
	foe.yes = 1
	me.yes = 0
	g.destroy(angel)
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.LIBRARY, "the controller as it died said yes")
	assert_eq(g.players[0].library.back(), angel, "its owner's library")
	assert_eq(me.asked.size(), 0)


# ----------------------------------------------------------- Bellowing Fiend --

func test_bellowing_fiend_damaging_a_creature_burns_both_players() -> void:
	var fiend := put_battlefield(0, "Bellowing Fiend")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(fiend, TargetRef.card(bears), 3)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 17, "that creature's controller, as it last existed")
	assert_eq(g.players[0].life, 17, "and you")
	g.deal_damage(fiend, TargetRef.player(1), 3)
	assert_true(g.stack.is_empty(), "damage to a player is not damage to a creature")
	var own := put_battlefield(0, "Hill Giant")
	g.deal_damage(fiend, TargetRef.card(own), 1)
	resolve_stack()
	assert_eq(g.players[0].life, 11, "its own creature: 3 and 3 more to you")
	assert_eq(g.players[1].life, 14)


func test_bellowing_fiend_in_combat_under_fifth_edition() -> void:
	g.rules.set_edition("fifth")
	var fiend := put_battlefield(0, "Bellowing Fiend")
	var wall := put_battlefield(1, "Wall of Air")
	run_combat([fiend.id], {wall.id: fiend.id})
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[0].life, 17)


# --------------------------------------------------------------- Chaotic Goo --

func test_chaotic_goo_enters_with_three_and_gambles_a_counter() -> void:
	var goo := put_battlefield(0, "Chaotic Goo")
	assert_eq(_counter(goo, "+1/+1"), 3)
	assert_eq([goo.cur_power, goo.cur_toughness], [3, 3])
	me.yes = 1
	_to_upkeep(0)
	_seed_flip(true)
	resolve_stack()
	assert_eq(_counter(goo, "+1/+1"), 4, "won the flip")
	_to_upkeep(0)
	_seed_flip(false)
	resolve_stack()
	assert_eq(_counter(goo, "+1/+1"), 3, "lost the flip")
	me.yes = 0
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_counter(goo, "+1/+1"), 3, "declined: no flip")


# --------------------------------------------------------- Cloudchaser Eagle --

func test_cloudchaser_eagle_destroys_an_enchantment_theirs_first() -> void:
	var mine := put_battlefield(0, "Crusade")
	var theirs := put_battlefield(1, "Bad Moon")
	var eagle := give_hand(0, "Cloudchaser Eagle")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, eagle, []))
	resolve_stack()
	assert_eq(eagle.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)


func test_cloudchaser_eagle_must_take_your_own_when_it_is_the_only_one() -> void:
	var mine := put_battlefield(0, "Crusade")
	put_battlefield(0, "Cloudchaser Eagle")
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "the target is not optional (CR 603.3d)")


func test_cloudchaser_eagle_without_an_enchantment_has_no_trigger() -> void:
	put_battlefield(1, "Grizzly Bears")
	var eagle := put_battlefield(0, "Cloudchaser Eagle")
	assert_true(g.stack.is_empty(), "no legal target: the trigger is removed")
	assert_eq(eagle.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------- Commander Greven il-Vec --

func test_commander_greven_sacrifices_another_creature_first() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var greven := put_battlefield(0, "Commander Greven il-Vec")
	assert_true(greven.has_keyword(Mtg.Keyword.FEAR))
	assert_true((greven.data.supertypes & Mtg.Supertype.LEGENDARY) != 0)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(greven.zone, Mtg.Zone.BATTLEFIELD)


func test_commander_greven_alone_sacrifices_itself() -> void:
	var theirs := put_battlefield(1, "Grizzly Bears")
	var greven := put_battlefield(0, "Commander Greven il-Vec")
	resolve_stack()
	assert_eq(greven.zone, Mtg.Zone.GRAVEYARD, "you sacrifice only what you control")
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)


# -------------------------------------------------------- Death Pits of Rath --

func test_death_pits_destroys_any_creature_dealt_damage_without_regeneration() -> void:
	put_battlefield(1, "Death Pits of Rath")
	var giant := put_battlefield(0, "Hill Giant")
	var skeletons := put_battlefield(0, "Drudge Skeletons")
	var source := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(source, TargetRef.card(giant), 1)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "1 damage is enough")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, skeletons, 0, []))
	resolve_stack()
	assert_eq(skeletons.regeneration_shields, 1)
	g.deal_damage(source, TargetRef.card(skeletons), 1)
	resolve_stack()
	assert_eq(skeletons.zone, Mtg.Zone.GRAVEYARD, "it can't be regenerated")
	g.deal_damage(source, TargetRef.player(0), 2)
	assert_true(g.stack.is_empty(), "a player is no creature")


func _death_pits_combat() -> void:
	put_battlefield(0, "Death Pits of Rath")
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	run_combat([giant.id], {wall.id: giant.id})
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "3 damage on a 0/8 wall")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "dealt no damage")


func test_death_pits_in_combat_under_modern_rules() -> void:
	_death_pits_combat()


func test_death_pits_in_combat_under_fifth_edition() -> void:
	g.rules.set_edition("fifth")
	_death_pits_combat()


# ------------------------------------------------------------- Dirtcowl Wurm --

func test_dirtcowl_wurm_grows_when_an_opponent_plays_a_land() -> void:
	var wurm := put_battlefield(0, "Dirtcowl Wurm")
	assert_ok(g.play_land(0, give_hand(0, "Forest")))
	assert_true(g.stack.is_empty(), "your own land does nothing")
	advance_to_next_turn()
	assert_ok(g.play_land(1, give_hand(1, "Forest")))
	resolve_stack()
	assert_eq(_counter(wurm, "+1/+1"), 1)
	assert_eq([wurm.cur_power, wurm.cur_toughness], [4, 5])
	put_battlefield(1, "Forest")
	assert_true(g.stack.is_empty(), "a land put onto the battlefield is not played")


# ------------------------------------------------------------ Field of Souls --

func test_field_of_souls_makes_a_spirit_for_each_nontoken_creature_of_yours() -> void:
	put_battlefield(0, "Field of Souls")
	var bears := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	g.destroy(bears)
	resolve_stack()
	var spirits := _named(0, "Spirit")
	assert_eq(spirits.size(), 1)
	assert_eq([spirits[0].cur_power, spirits[0].cur_toughness], [1, 1])
	assert_true(spirits[0].has_keyword(Mtg.Keyword.FLYING))
	assert_true(spirits[0].has_color(Mtg.ManaColor.W))
	g.destroy(theirs)
	resolve_stack()
	assert_eq(_named(0, "Spirit").size(), 1, "an opponent's creature goes to their graveyard")
	g.destroy(spirits[0])
	resolve_stack()
	assert_eq(_named(0, "Spirit").size(), 0, "a token is no nontoken creature")
	# Your card dying under the opponent's control reaches YOUR graveyard.
	var lent := put_battlefield(0, "Grizzly Bears")
	g.change_control(lent, 1)
	g.destroy(lent)
	resolve_stack()
	assert_eq(_named(0, "Spirit").size(), 1)


# ------------------------------------------------------------ Fugitive Druid --

func test_fugitive_druid_draws_only_for_aura_spells() -> void:
	var druid := put_battlefield(0, "Fugitive Druid")
	var strength := give_hand(0, "Holy Strength")
	add_mana(0, Mtg.ManaColor.W)
	var hand := g.players[0].hand.size()
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(druid)]))
	assert_eq(g.stack.size(), 2, "the Aura spell targets it")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand, "cast one, drew one")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(druid)]))
	assert_eq(g.stack.size(), 1, "an instant is no Aura spell")
	resolve_stack()


func test_fugitive_druid_draws_for_its_controller_when_an_opponent_enchants_it() -> void:
	var druid := put_battlefield(0, "Fugitive Druid")
	advance_to_next_turn()
	var weak := give_hand(1, "Unholy Strength")
	add_mana(1, Mtg.ManaColor.B)
	var hand := g.players[0].hand.size()
	assert_ok(g.cast_spell(1, weak, [TargetRef.card(druid)]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)


# --------------------------------------------------- Havoc, Insight, Warmth --

func test_havoc_insight_and_warmth_answer_an_opponents_coloured_spells() -> void:
	put_battlefield(0, "Havoc")
	put_battlefield(0, "Insight")
	put_battlefield(0, "Warmth")
	var bears := put_battlefield(1, "Grizzly Bears")
	var hand := g.players[0].hand.size()
	# White: Havoc.
	g.pass_priority(0)
	var salve := give_hand(1, "Healing Salve")
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, salve, [TargetRef.player(1)]))
	assert_eq(g.stack.size(), 2, "Havoc only")
	resolve_stack()
	assert_eq(g.players[1].life, 21, "lost 2, then gained 3")
	# Green: Insight.
	g.pass_priority(0)
	var growth := give_hand(1, "Giant Growth")
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, growth, [TargetRef.card(bears)]))
	assert_eq(g.stack.size(), 2)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1, "you draw")
	# Red: Warmth.
	g.pass_priority(0)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 19, "gained 2, then took 3")
	# Your own spells trigger none of them.
	var own := give_hand(0, "Healing Salve")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, own, [TargetRef.player(0)]))
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(g.players[0].life, 22)


# ---------------------------------------------------------------- Jackal Pup --

func test_jackal_pup_passes_all_the_damage_it_is_dealt_to_you() -> void:
	var pup := put_battlefield(0, "Jackal Pup")
	g.pass_priority(0)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(pup)]))
	resolve_stack()
	assert_eq(pup.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 17, "all 3, from the Pup as it last existed")


func _pup_combat() -> void:
	var pup := put_battlefield(0, "Jackal Pup")
	var bears := put_battlefield(1, "Grizzly Bears")
	run_combat([pup.id], {bears.id: pup.id})
	resolve_stack()
	assert_eq(pup.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 18)


func test_jackal_pup_in_combat_under_modern_rules() -> void:
	_pup_combat()


func test_jackal_pup_in_combat_under_fifth_edition() -> void:
	g.rules.set_edition("fifth")
	_pup_combat()


# ---------------------------------------------------------------- Kezzerdrix --

func test_kezzerdrix_bites_only_while_the_opponent_has_no_creature() -> void:
	var kez := put_battlefield(0, "Kezzerdrix")
	assert_true(kez.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	_to_upkeep(0)
	resolve_stack()
	assert_eq(g.players[0].life, 16)
	var bears := put_battlefield(1, "Grizzly Bears")
	_to_upkeep(0)
	assert_true(g.stack.is_empty(), "the opponent controls a creature")
	g.destroy(bears)
	_to_upkeep(0)
	assert_eq(g.stack.size(), 1)
	put_battlefield(1, "Grizzly Bears")
	resolve_stack()
	assert_eq(g.players[0].life, 16, "rechecked on resolution (CR 603.4)")


# ----------------------------------------------------------- Legacy's Allure --

func test_legacys_allure_saves_treasure_then_steals_that_small_a_creature() -> void:
	var allure := put_battlefield(0, "Legacy's Allure")
	var bears := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	me.yes = 1
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_counter(allure, "treasure"), 1)
	assert_refused(g.activate_ability(0, allure, 0, [TargetRef.card(bears)]))
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_counter(allure, "treasure"), 2)
	assert_refused(g.activate_ability(0, allure, 0, [TargetRef.card(giant)]))
	assert_eq(allure.zone, Mtg.Zone.BATTLEFIELD, "a refused activation pays nothing")
	assert_ok(g.activate_ability(0, allure, 0, [TargetRef.card(bears)]))
	assert_eq(allure.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(bears.controller_id, 0, "its last two counters still count (CR 608.2h)")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(bears.controller_id, 0, "indefinitely")
	assert_eq(giant.controller_id, 1)


func test_legacys_allure_counter_is_optional() -> void:
	var allure := put_battlefield(0, "Legacy's Allure")
	me.yes = 0
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_counter(allure, "treasure"), 0)


# ----------------------------------------------------------------- Magmasaur --

func test_magmasaur_sheds_a_counter_or_erupts_over_the_ground() -> void:
	var saur := put_battlefield(0, "Magmasaur")
	assert_eq([saur.cur_power, saur.cur_toughness], [5, 5])
	me.yes = 1
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_counter(saur, "+1/+1"), 4)
	var bears := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var angel := put_battlefield(1, "Serra Angel")
	me.yes = 0
	_to_upkeep(0)
	resolve_stack()
	assert_eq(saur.zone, Mtg.Zone.GRAVEYARD, "not removed: sacrificed")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "its controller's creatures too")
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(angel.damage, 0, "a flyer is spared")
	assert_eq(g.players[0].life, 16, "four counters as it left: each player")
	assert_eq(g.players[1].life, 16)


func test_magmasaur_bounced_in_response_still_erupts_for_its_last_counters() -> void:
	var saur := put_battlefield(0, "Magmasaur")
	var bears := put_battlefield(1, "Grizzly Bears")
	me.yes = 1
	_to_upkeep(0)
	assert_eq(g.stack.size(), 1)
	var unsummon := give_hand(0, "Unsummon")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, unsummon, [TargetRef.card(saur)]))
	resolve_stack()
	assert_eq(saur.zone, Mtg.Zone.HAND)
	assert_eq(me.asked.size(), 0, "no counter can be removed from a card in a hand")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "five counters as it last existed (CR 608.2h)")
	assert_eq(g.players[0].life, 15)
	assert_eq(g.players[1].life, 15)


# -------------------------------------------------------------- Mongrel Pack --

func test_mongrel_pack_leaves_four_dogs_only_when_it_dies_during_combat() -> void:
	var pack := put_battlefield(0, "Mongrel Pack")
	var giant := put_battlefield(1, "Hill Giant")
	run_combat([pack.id], {giant.id: pack.id})
	resolve_stack()
	assert_eq(pack.zone, Mtg.Zone.GRAVEYARD)
	var dogs := _named(0, "Dog")
	assert_eq(dogs.size(), 4)
	for d in dogs:
		assert_eq([d.cur_power, d.cur_toughness], [1, 1])
		assert_true(d.has_color(Mtg.ManaColor.G))
	advance_to_next_turn()
	var second := put_battlefield(0, "Mongrel Pack")
	g.destroy(second)
	resolve_stack()
	assert_eq(_named(0, "Dog").size(), 4, "outside combat: no dogs")


# ------------------------------------------------------------- Orim's Prayer --

func test_orims_prayer_gains_a_life_for_each_creature_attacking_you() -> void:
	put_battlefield(0, "Orim's Prayer")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Savannah Lions")
	var mine := put_battlefield(0, "Grizzly Bears")
	run_combat([mine.id])
	assert_eq(g.players[0].life, 20, "your own attack is not one on you")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [a.id, b.id]))
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(g.players[0].life, 22)


# -------------------------------------------------------------- Rathi Dragon --

func test_rathi_dragon_stays_for_two_mountains() -> void:
	for n in 3: put_battlefield(0, "Mountain")
	put_battlefield(0, "Forest")
	me.yes = 1
	var dragon := put_battlefield(0, "Rathi Dragon")
	assert_true(dragon.has_keyword(Mtg.Keyword.FLYING))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(_named(0, "Mountain").size(), 1, "two Mountains went")
	assert_eq(_named(0, "Forest").size(), 1)


func test_rathi_dragon_goes_when_declined_or_short_of_mountains() -> void:
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	me.yes = 0
	var dragon := put_battlefield(0, "Rathi Dragon")
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_named(0, "Mountain").size(), 2)
	g.destroy(_named(0, "Mountain")[0])
	me.yes = 1
	var second := put_battlefield(0, "Rathi Dragon")
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "one Mountain is not two")
	assert_eq(_named(0, "Mountain").size(), 1)


# ------------------------------------------------------------------- Recycle --

func test_recycle_draws_a_card_for_each_card_you_play() -> void:
	put_battlefield(0, "Recycle")
	var forest := give_hand(0, "Forest")
	var hand := g.players[0].hand.size()
	assert_ok(g.play_land(0, forest))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand, "played a land, drew a card")
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	hand = g.players[0].hand.size()
	assert_ok(g.cast_spell(0, bears, []))
	assert_eq(g.stack.size(), 2, "the draw waits above the spell")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand, "cast a spell, drew a card")
	advance_to_next_turn()
	assert_ok(g.play_land(1, give_hand(1, "Forest")))
	assert_true(g.stack.is_empty(), "the opponent's plays draw nothing")


func test_recycle_skips_your_draw_step_and_caps_your_hand_at_two() -> void:
	put_battlefield(0, "Recycle")
	for n in 4: give_hand(0, "Forest")
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), 2, "discarded to two at cleanup")
	assert_eq(g.players[1].max_hand_size, 7, "only yours")
	var hand := g.players[0].hand.size()
	var library := g.players[0].library.size()
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_eq(g.players[0].hand.size(), hand, "no draw step")
	assert_eq(g.players[0].library.size(), library)


# ---------------------------------------------------------------- Sarcomancy --

func test_sarcomancy_makes_a_zombie_and_bites_when_there_is_none() -> void:
	put_battlefield(0, "Sarcomancy")
	resolve_stack()
	var zombies := _named(0, "Zombie")
	assert_eq(zombies.size(), 1)
	assert_eq([zombies[0].cur_power, zombies[0].cur_toughness], [2, 2])
	assert_true(zombies[0].has_color(Mtg.ManaColor.B))
	_to_upkeep(0)
	assert_true(g.stack.is_empty(), "a Zombie is on the battlefield")
	g.destroy(zombies[0])
	var theirs := put_battlefield(1, "Scathe Zombies")
	_to_upkeep(0)
	assert_true(g.stack.is_empty(), "anyone's Zombie counts")
	g.destroy(theirs)
	_to_upkeep(0)
	resolve_stack()
	assert_eq(g.players[0].life, 19)


# ------------------------------------------------------------ Segmented Wurm --

func test_segmented_wurm_shrinks_each_time_it_is_targeted() -> void:
	var wurm := put_battlefield(0, "Segmented Wurm")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(wurm)]))
	assert_eq(g.stack.size(), 2, "its controller's own spell too")
	resolve_stack()
	assert_eq(_counter(wurm, "-1/-1"), 1)
	assert_eq([wurm.cur_power, wurm.cur_toughness], [7, 7])
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(giant, TargetRef.card(wurm), 1)
	assert_true(g.stack.is_empty(), "damage alone targets nothing")


# -------------------------------------------------------- Servant of Volrath --

func test_servant_of_volrath_leaving_costs_its_controller_a_creature() -> void:
	var servant := put_battlefield(0, "Servant of Volrath")
	var bears := put_battlefield(0, "Grizzly Bears")
	var unsummon := give_hand(0, "Unsummon")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, unsummon, [TargetRef.card(servant)]))
	resolve_stack()
	assert_eq(servant.zone, Mtg.Zone.HAND)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "leaving is not only dying")
	var second := put_battlefield(0, "Servant of Volrath")
	g.destroy(second)
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "nothing left to sacrifice: nothing happens")


func test_servant_of_volrath_stolen_costs_the_thief() -> void:
	var servant := put_battlefield(0, "Servant of Volrath")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	g.change_control(servant, 1)
	g.destroy(servant)
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "its controller as it left (CR 603.3a)")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------------- Shocker --

func test_shocker_makes_the_player_it_hits_redraw_their_hand() -> void:
	var shocker := put_battlefield(0, "Shocker")
	var cards := [give_hand(1, "Forest"), give_hand(1, "Island"), give_hand(1, "Lightning Bolt")]
	var library := g.players[1].library.size()
	run_combat([shocker.id])
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	for c in cards: assert_eq(c.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].hand.size(), 3, "drew that many")
	assert_eq(g.players[1].library.size(), library - 3)


func test_shocker_blocked_hits_no_player() -> void:
	var shocker := put_battlefield(0, "Shocker")
	var wall := put_battlefield(1, "Wall of Air")
	var card := give_hand(1, "Forest")
	run_combat([shocker.id], {wall.id: shocker.id})
	resolve_stack()
	assert_eq(card.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------- Spirit Mirror --

func test_spirit_mirror_keeps_one_reflection_and_can_break_it() -> void:
	var mirror := put_battlefield(0, "Spirit Mirror")
	_to_upkeep(0)
	resolve_stack()
	var reflections := _named(0, "Reflection")
	assert_eq(reflections.size(), 1)
	assert_eq([reflections[0].cur_power, reflections[0].cur_toughness], [2, 2])
	assert_true(reflections[0].has_color(Mtg.ManaColor.W))
	_to_upkeep(0)
	assert_true(g.stack.is_empty(), "a Reflection token is on the battlefield")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, mirror, 0, [TargetRef.card(bears)]))
	assert_ok(g.activate_ability(0, mirror, 0, [TargetRef.card(reflections[0])]))
	resolve_stack()
	assert_eq(_named(0, "Reflection").size(), 0)
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_named(0, "Reflection").size(), 1)


# --------------------------------------------------------- Staunch Defenders --

func test_staunch_defenders_gains_four_life() -> void:
	var defenders := give_hand(0, "Staunch Defenders")
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, defenders, []))
	resolve_stack()
	assert_eq(defenders.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 24)


# ----------------------------------------------------- Unstable Shapeshifter --

func test_unstable_shapeshifter_becomes_each_creature_that_enters() -> void:
	var shifter := put_battlefield(0, "Unstable Shapeshifter")
	assert_true(g.stack.is_empty(), "its own arrival is not another creature")
	put_battlefield(1, "Hill Giant")
	resolve_stack()
	assert_eq(shifter.data.card_name, "Hill Giant")
	assert_eq([shifter.cur_power, shifter.cur_toughness], [3, 3])
	assert_eq(shifter.controller_id, 0)
	put_battlefield(0, "Serra Angel")
	assert_eq(g.stack.size(), 1, "it kept this ability")
	resolve_stack()
	assert_eq(shifter.data.card_name, "Serra Angel")
	assert_true(shifter.has_keyword(Mtg.Keyword.FLYING))
	assert_true(shifter.has_color(Mtg.ManaColor.W), "the colour is copied")
	put_battlefield(1, "Forest")
	assert_true(g.stack.is_empty(), "a land is no creature")


func test_unstable_shapeshifter_copies_a_creature_that_left_as_it_last_existed() -> void:
	var shifter := put_battlefield(0, "Unstable Shapeshifter")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_eq(g.stack.size(), 1)
	g.destroy(bears)
	resolve_stack()
	assert_eq(shifter.data.card_name, "Grizzly Bears")
	assert_eq([shifter.cur_power, shifter.cur_toughness], [2, 2])


# ------------------------------------------------------------- Verdant Force --

func test_verdant_force_makes_a_saproling_every_upkeep() -> void:
	put_battlefield(0, "Verdant Force")
	_to_upkeep(1)
	resolve_stack()
	assert_eq(_named(0, "Saproling").size(), 1, "the opponent's upkeep too, for its controller")
	assert_eq(_named(1, "Saproling").size(), 0)
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_named(0, "Saproling").size(), 2)


# ----------------------------------------------------------------- Wild Wurm --

func test_wild_wurm_stays_on_a_won_flip_and_goes_home_on_a_lost_one() -> void:
	var wurm := put_battlefield(0, "Wild Wurm")
	_seed_flip(true)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	var second := put_battlefield(0, "Wild Wurm")
	_seed_flip(false)
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.HAND)
