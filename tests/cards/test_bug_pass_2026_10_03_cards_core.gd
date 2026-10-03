extends GameTest
## Bug pass of 2026-10-03 over the base pool's card files (2ed/4ed/arn/atq/
## leg/drk/past/phpr). Each test pins one printed clause a card was not
## honouring: "whenever this blocks" heard once per band member, triggered
## abilities that gave up when their source had left (CR 603.6 / 608.2h),
## effects that died with — or outlived — the permanent they belong to,
## a remembered id that survived a zone change (CR 400.7), Eureka's Auras,
## and a mana query that consumed the game's RNG.


## A seat that says yes to every yes/no question and records who it was.
class Eager extends DecisionAgent:
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String,
			_hint: bool) -> bool:
		asked.append(prompt)
		return true


## A seat that records every yes/no question and declines it.
class Spy extends DecisionAgent:
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String,
			_hint: bool) -> bool:
		asked.append(prompt)
		return false


## Opens Fifth Edition's damage-prevention window, so the regeneration
## window it carries can be reached.
class Duelist extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


## Pass (declaring nothing) until [param pid]'s [param step] of a later
## turn has something on the stack — the moment a beginning-of-step
## trigger is waiting to resolve.
func _to_trigger(step: int, pid: int) -> void:
	var guard := 0
	while not g.game_over and guard < 600 and not (g.active_player == pid
			and g.turn_number > 1 and g.current_step() == step
			and not g.stack.is_empty()):
		_advance_once()
		guard += 1
	assert_lt(guard, 600, "never reached the trigger")


## Pass until [param pid]'s upkeep of a later turn, with priority.
func _to_upkeep(pid: int) -> void:
	var guard := 0
	while not g.game_over and guard < 600 and not (g.active_player == pid
			and g.turn_number > 1 and g.current_step() == Mtg.Step.UPKEEP):
		_advance_once()
		guard += 1
	assert_lt(guard, 600, "never reached the upkeep")


# ----------------------------------------- A. "whenever it blocks", once --

func test_giant_badger_blocking_a_band_gets_plus_two_once() -> void:
	var h1 := put_battlefield(0, "Benalish Hero")
	var h2 := put_battlefield(0, "Benalish Hero")
	var badger := put_battlefield(1, "Giant Badger")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [h1.id, h2.id], [[h1.id, h2.id]]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {badger.id: h1.id}))
	resolve_stack()
	assert_eq(badger.cur_power, 4, "one block, one +2/+2 — not one per band member")
	assert_eq(badger.cur_toughness, 4)


func test_time_elemental_blocking_a_band_burns_its_controller_once() -> void:
	var h1 := put_battlefield(0, "Benalish Hero")
	var h2 := put_battlefield(0, "Benalish Hero")
	var elemental := put_battlefield(1, "Time Elemental")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [h1.id, h2.id], [[h1.id, h2.id]]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {elemental.id: h1.id}))
	advance_to_step(Mtg.Step.MAIN2)
	resolve_stack()
	assert_eq(g.players[1].life, 15, "five damage for one block, not ten")
	assert_ne(elemental.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------ B. triggers resolve without their source (LKI) --

func test_juzam_djinn_bites_even_when_bounced_in_response() -> void:
	var djinn := put_battlefield(0, "Juzám Djinn")
	_to_trigger(Mtg.Step.UPKEEP, 0)
	var before := g.players[0].life
	g.return_to_hand(djinn)
	resolve_stack()
	assert_eq(g.players[0].life, before - 1, "CR 603.6: the bite resolves anyway")


func test_serendib_efreet_bites_even_when_bounced_in_response() -> void:
	var efreet := put_battlefield(0, "Serendib Efreet")
	_to_trigger(Mtg.Step.UPKEEP, 0)
	var before := g.players[0].life
	g.return_to_hand(efreet)
	resolve_stack()
	assert_eq(g.players[0].life, before - 1)


func test_elder_spawn_bounced_in_response_still_deals_six() -> void:
	var spawn := put_battlefield(0, "Elder Spawn")
	_to_trigger(Mtg.Step.UPKEEP, 0)
	g.return_to_hand(spawn)
	resolve_stack()
	assert_eq(spawn.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 14, "no Island paid: it deals 6 damage to you")


func test_voodoo_doll_bounced_in_response_still_backfires() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var doll := put_battlefield(0, "Voodoo Doll")
	g.add_counters(doll, "pin", 3)
	advance_to_step(Mtg.Step.END)
	assert_false(g.stack.is_empty(), "the end-step trigger is waiting")
	g.return_to_hand(doll)
	resolve_stack()
	assert_eq(g.players[0].life, 17, "it was untapped when it left, with 3 pins")


## The intervening "if" is rechecked against the Doll AS IT LAST EXISTED
## (CR 603.4, 608.2h): tapped in response and then removed, it was tapped
## when it left — no backfire. (CardInstance.last_tapped; the ledger row
## that judged a departed Doll untapped is gone, 2026-10-03.)
func test_voodoo_doll_tapped_then_bounced_in_response_does_not_backfire() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var doll := put_battlefield(0, "Voodoo Doll")
	g.add_counters(doll, "pin", 3)
	advance_to_step(Mtg.Step.END)
	assert_false(g.stack.is_empty(), "the end-step trigger is waiting")
	g.tap_permanent(doll)
	g.return_to_hand(doll)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "it was tapped when it left")


func test_primordial_ooze_bounced_in_response_charges_its_last_size() -> void:
	var ooze := put_battlefield(0, "Primordial Ooze")
	ooze.summoning_sick = true   # no forced attack on turn 1
	g.add_counters(ooze, "+1/+1", 3)
	_to_trigger(Mtg.Step.UPKEEP, 0)
	g.return_to_hand(ooze)
	resolve_stack()
	assert_eq(g.players[0].life, 17,
		"X is the counters it last had (3); no mana to pay, so 3 damage")


func test_floral_spuzzem_killed_in_response_still_takes_the_artifact() -> void:
	var spuzzem := put_battlefield(0, "Floral Spuzzem")
	var disk := put_battlefield(1, "Nevinyrral's Disk")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [spuzzem.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_false(g.stack.is_empty(), "the unblocked trigger is waiting")
	g.destroy(spuzzem)
	resolve_stack()
	assert_eq(disk.zone, Mtg.Zone.GRAVEYARD, "the trigger resolved without its source")


func test_imprison_destroyed_in_response_still_collects_the_attack_toll() -> void:
	var prisoner := put_battlefield(1, "Hill Giant")
	var imprison := give_hand(0, "Imprison")
	put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, imprison, [TargetRef.card(prisoner)]))
	resolve_stack()
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [prisoner.id]))
	assert_false(g.stack.is_empty(), "the toll trigger is waiting")
	g.destroy(imprison)
	resolve_stack()
	assert_false(g.combat.attackers.has(prisoner.id),
		"the toll was still payable, and paying hauls the creature back")


func test_imprison_destroyed_in_response_still_counters_the_tap_ability() -> void:
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	var imprison := give_hand(0, "Imprison")
	put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, imprison, [TargetRef.card(sorcerer)]))
	resolve_stack()
	advance_to_next_turn()
	assert_ok(g.activate_ability(1, sorcerer, 0, [TargetRef.player(0)]))
	assert_eq(g.stack.size(), 2, "the ping and Imprison's trigger above it")
	g.destroy(imprison)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the {1} was paid and the ping countered")


func test_armageddon_clock_destroyed_in_response_burns_by_its_last_counters() -> void:
	var clock := put_battlefield(0, "Armageddon Clock")
	g.add_counters(clock, "doom", 2)
	_to_trigger(Mtg.Step.DRAW, 0)       # the upkeep tick made it 3
	var p0 := g.players[0].life
	var p1 := g.players[1].life
	g.destroy(clock)
	resolve_stack()
	assert_eq(g.players[0].life, p0 - 3, "last known doom counters: 3")
	assert_eq(g.players[1].life, p1 - 3)


func test_the_fallen_killed_in_response_still_bites_whom_it_remembered() -> void:
	var fallen := put_battlefield(0, "The Fallen")
	g.deal_damage(fallen, TargetRef.player(1), 2)
	resolve_stack()
	_to_trigger(Mtg.Step.UPKEEP, 0)
	var before := g.players[1].life
	g.destroy(fallen)
	resolve_stack()
	assert_eq(g.players[1].life, before - 1)


func test_psychic_allergy_destroyed_in_response_still_burns() -> void:
	var allergy := put_battlefield(0, "Psychic Allergy")
	resolve_stack()                     # the colour choice
	allergy.memory["color"] = Mtg.ManaColor.G
	for _i in 3:
		put_battlefield(1, "Grizzly Bears")
	_to_trigger(Mtg.Step.UPKEEP, 1)
	var before := g.players[1].life
	g.destroy(allergy)
	resolve_stack()
	assert_eq(g.players[1].life, before - 3, "three green permanents, the colour it had")


func test_dance_of_many_gone_before_its_etb_still_makes_a_token_that_stays() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var dance := give_hand(0, "Dance of Many")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, dance, []))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))       # the enchantment resolves
	assert_eq(dance.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.stack.size(), 1, "its ETB is waiting, aimed at the Bears")
	g.destroy(dance)
	resolve_stack()
	var token: CardInstance = null
	for inst in g.players[0].battlefield:
		if inst.is_token:
			token = inst
	assert_not_null(token, "the token is still created")
	assert_eq(token.data.card_name, bear.data.card_name)
	advance_to_next_turn()
	assert_eq(token.zone, Mtg.Zone.BATTLEFIELD,
		"nothing links it to a Dance that had already left")


## A copy of a FACE-DOWN creature is a nameless, colourless 2/2 (CR 707.2,
## 708.2) — Dance of Many read the card underneath, as Clone did, and
## would have made a 5/5 flying Shivan Dragon token (and named it).
func test_dance_of_many_copying_a_face_down_creature_makes_a_two_two() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var dragon := give_hand(1, "Shivan Dragon")
	g.put_from_hand_face_down(dragon, 1)      # Illusionary Mask's route
	assert_true(dragon.face_down)
	var dance := give_hand(0, "Dance of Many")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, dance, []))
	resolve_stack()
	var token: CardInstance = null
	for inst in g.players[0].battlefield:
		if inst.is_token:
			token = inst
	assert_not_null(token, "the masked creature is a legal target")
	assert_eq(token.cur_power, 2)
	assert_eq(token.cur_toughness, 2)
	assert_false(token.has_keyword(Mtg.Keyword.FLYING))
	assert_ne(token.data.card_name, "Shivan Dragon")
	for line in g.log_lines:
		assert_false(String(line).contains("Shivan Dragon"), "the log names the hidden card: %s" % line)


# ------------------------------ C. effects tied to the wrong lifetime --

func test_raging_river_restriction_outlives_the_river_this_combat() -> void:
	var river := put_battlefield(0, "Raging River")
	var attacker := put_battlefield(0, "Hill Giant")
	var one := put_battlefield(1, "Grizzly Bears")
	var two := put_battlefield(1, "Mons's Goblin Raiders")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	var labels: Dictionary = river.memory.get("labels", {})
	var chosen: Array = river.memory.get(String(labels[attacker.id]), [])
	var outsider := two if chosen.has(one.id) else one
	assert_false(chosen.has(outsider.id))
	g.destroy(river)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {outsider.id: attacker.id}),
		"can't be blocked except by")


func test_island_sanctuary_shield_outlives_the_sanctuary() -> void:
	g.set_agent(0, Eager.new())
	advance_to_step(Mtg.Step.MAIN1)
	var sanctuary := put_battlefield(0, "Island Sanctuary")
	var wurm := put_battlefield(1, "Craw Wurm")
	advance_to_next_turn()
	advance_to_next_turn()              # p0 skips the draw: the gates close
	advance_to_next_turn()              # p1's turn
	assert_true(wurm.cur_cant_attack)
	g.destroy(sanctuary)
	assert_true(wurm.cur_cant_attack,
		"the effect lasts until your next turn, not while the enchantment stays")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, [wurm.id]))


func test_island_sanctuary_shield_holds_through_an_extra_turn() -> void:
	g.set_agent(0, Eager.new())
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Island Sanctuary")
	var wurm := put_battlefield(1, "Craw Wurm")
	advance_to_next_turn()
	advance_to_next_turn()              # p0 skips the draw
	advance_to_next_turn()              # p1's turn
	g.add_extra_turn(1)
	advance_to_next_turn()              # p1's EXTRA turn: p0's next turn has not begun
	assert_eq(g.active_player, 1)
	assert_true(wurm.cur_cant_attack, "until YOUR next turn, however many turns pass")
	g.set_agent(0, Spy.new())           # p0 draws normally this time
	advance_to_next_turn()              # p0's next turn: the shield ends
	assert_eq(g.active_player, 0)
	assert_false(wurm.cur_cant_attack)


func test_tangle_kelp_gone_before_the_untap_lets_the_creature_untap() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var kelp := give_hand(1, "Tangle Kelp")
	g.attach_aura_from_anywhere(kelp, bear, 1)
	resolve_stack()                     # its ETB taps the Bears
	bear.tapped = false                 # setup: let it attack this turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_next_turn()              # p1's turn
	g.destroy(kelp)
	advance_to_next_turn()              # p0's untap step has passed
	assert_false(bear.tapped, "no Kelp, no untap restriction")


func test_tangle_kelp_still_holds_an_attacker_down() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var kelp := give_hand(1, "Tangle Kelp")
	g.attach_aura_from_anywhere(kelp, bear, 1)
	resolve_stack()
	bear.tapped = false
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(bear.tapped, "it attacked during its controller's last turn")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(bear.tapped, "it did not attack last turn: it untaps")


func test_cyclopean_tomb_dying_in_response_still_mires_the_land() -> void:
	var tomb := put_battlefield(0, "Cyclopean Tomb")
	var forest := put_battlefield(1, "Forest")
	_to_upkeep(0)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tomb, 0, [TargetRef.card(forest)]))
	g.destroy(tomb)
	resolve_stack()
	assert_eq(int(forest.counters.get("mire", 0)), 1)
	assert_true(forest.has_subtype("swamp"),
		"the land is a Swamp for as long as it has a mire counter")
	assert_false(forest.has_subtype("forest"))
	# "...a land that a mire counter was put onto with this artifact" —
	# the reversion takes it back at the next upkeep.
	advance_to_next_turn()
	_to_upkeep(0)
	resolve_stack()
	assert_eq(int(forest.counters.get("mire", 0)), 0, "reverted")
	assert_true(forest.has_subtype("forest"))


func test_gaea_s_liege_forest_does_not_come_back_with_a_new_liege() -> void:
	put_battlefield(0, "Forest")        # the Liege is */* — give it a body
	put_battlefield(0, "Forest")
	var liege := put_battlefield(0, "Gaea's Liege")
	var island := put_battlefield(1, "Island")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, liege, 0, [TargetRef.card(island)]))
	g.destroy(liege)
	resolve_stack()
	assert_false(island.has_subtype("forest"), "the duration had already ended")
	g.reanimate(liege, 0)
	g.recalculate()
	assert_true(island.has_subtype("island"),
		"a new Liege did not touch this land (CR 400.7)")
	assert_false(island.has_subtype("forest"))


# ------------------------------------------------- D. The Brute's shield --

func test_the_brute_regenerates_in_the_regeneration_window() -> void:
	g.rules.set_edition("fifth")
	g.set_agent(0, Duelist.new())
	g.set_agent(1, Duelist.new())
	var bears := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.MAIN1)
	var brute := give_hand(0, "The Brute")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, brute, [TargetRef.card(bears)]))
	resolve_stack()
	var ability: ActivatedAbility = brute.cur_activated_abilities[0]
	assert_true(ability.effects[0].is_regeneration, "it says what it is")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wurm.id: bears.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	var guard := 0
	while g.awaiting_damage_prevention and guard < 10:
		assert_ok(g.end_damage_prevention(g.priority_player))
		guard += 1
	assert_true(g.awaiting_regeneration, "the window opens for a regenerator")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.activate_ability(0, brute, 0, []))
	resolve_stack()
	guard = 0
	while (g.awaiting_regeneration or g.awaiting_damage_prevention) and guard < 10:
		assert_ok(g.end_damage_prevention(g.priority_player))
		guard += 1
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "regenerated")


# ------------------------ E. a remembered creature that left is gone --

func test_tawnos_s_weaponry_does_not_pump_a_recast_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var wurm := put_battlefield(0, "Craw Wurm")
	var gear := put_battlefield(0, "Tawnos's Weaponry")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, gear, 0, [TargetRef.card(wurm)]))
	resolve_stack()
	assert_eq(wurm.cur_power, 7)
	g.return_to_hand(wurm)
	g.put_from_hand_into_play(wurm, 0)
	assert_true(gear.tapped)
	assert_eq(wurm.cur_power, 6, "a new object (CR 400.7)")
	assert_eq(wurm.cur_toughness, 4)


func test_ashnod_s_battle_gear_does_not_hold_a_recast_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(0, "Hill Giant")
	var gear := put_battlefield(0, "Ashnod's Battle Gear")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, gear, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.cur_toughness, 1)
	g.return_to_hand(giant)
	g.put_from_hand_into_play(giant, 0)
	assert_eq(giant.cur_power, 3)
	assert_eq(giant.cur_toughness, 3)


func test_phyrexian_gremlins_do_not_lock_a_replayed_artifact() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var gremlins := put_battlefield(0, "Phyrexian Gremlins")
	var ring := put_battlefield(1, "Sol Ring")
	assert_ok(g.activate_ability(0, gremlins, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_true(ring.cur_skips_untap)
	g.return_to_hand(ring)
	g.put_from_hand_into_play(ring, 1)
	assert_true(gremlins.tapped)
	assert_false(ring.cur_skips_untap, "a new object (CR 400.7)")


# ---------------------------------------------- F. Eureka's Auras --

func test_eureka_attaches_an_aura_to_a_chosen_host() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Holy Strength")
	var eureka := give_hand(0, "Eureka")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, eureka, []))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD, "CR 303.4f: it enters attached")
	assert_eq(aura.attached_to, bear.id)
	assert_eq(bear.cur_power, 3)


func test_eureka_leaves_an_aura_with_nothing_to_enchant_in_hand() -> void:
	var aura := give_hand(0, "Holy Strength")
	var eureka := give_hand(0, "Eureka")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, eureka, []))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.HAND, "no legal object: it stays where it is")


## An Animate-Dead-style Aura put onto the battlefield chooses a creature
## card in a graveyard as it enters (CR 303.4f) and raises it, as its
## resolving spell would — the SIMPLIFIED row that never offered it is
## lifted (2026-10-03).
func test_eureka_puts_animate_dead_onto_a_graveyard_creature() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	g.destroy(angel, false)
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)
	var animate := give_hand(0, "Animate Dead")
	var eureka := give_hand(0, "Eureka")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, eureka, []))
	resolve_stack()
	assert_eq(animate.zone, Mtg.Zone.BATTLEFIELD, "offered, and put down")
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD, "the Angel is raised")
	assert_eq(angel.controller_id, 0, "under Animate Dead's controller")
	assert_eq(animate.attached_to, angel.id)


# --------------------------------------------- G. lower-severity fixes --

func test_hell_s_caretaker_may_sacrifice_itself() -> void:
	var keeper := put_battlefield(0, "Hell's Caretaker")
	var angel := _make_instance(0, "Serra Angel")
	angel.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(angel)
	_to_upkeep(0)
	assert_ok(g.activate_ability(0, keeper, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(keeper.zone, Mtg.Zone.GRAVEYARD, "it paid with itself")
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)


func test_transmute_artifact_sacrifices_a_live_artifact() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bears := put_battlefield(0, "Grizzly Bears")
	var mog := put_battlefield(0, "Ashnod's Transmogrant")
	assert_ok(g.activate_ability(0, mog, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_true(bears.is_type(Mtg.CardType.ARTIFACT))
	var ring := _make_instance(0, "Sol Ring")
	ring.zone = Mtg.Zone.LIBRARY
	g.players[0].library.append(ring)
	var transmute := give_hand(0, "Transmute Artifact")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, transmute, []))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "an artifact on the battlefield, by its live type")
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD)


func test_urza_s_mine_counts_the_tower_by_its_land_type() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mine := put_battlefield(0, "Urza's Mine")
	put_battlefield(0, "Urza's Power Plant")
	var tower := put_battlefield(0, "Urza's Tower")
	var presence := give_hand(0, "Evil Presence")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, presence, [TargetRef.card(tower)]))
	resolve_stack()
	assert_false(tower.has_subtype("tower"))
	var before := g.players[0].mana_pool.total()
	assert_ok(g.tap_for_mana(0, mine))
	assert_eq(g.players[0].mana_pool.total() - before, 1,
		"you no longer control an Urza's Tower")


func test_urza_s_tron_still_assembles() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Urza's Mine")
	put_battlefield(0, "Urza's Power Plant")
	var tower := put_battlefield(0, "Urza's Tower")
	assert_ok(g.tap_for_mana(0, tower))
	assert_eq(g.players[0].mana_pool.total(), 3)


func test_hellfire_does_not_count_a_phoenix_that_went_home() -> void:
	put_battlefield(1, "Firestorm Phoenix")
	var bear := put_battlefield(1, "Grizzly Bears")
	var hellfire := give_hand(0, "Hellfire")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, hellfire, []))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 16, "only the Bears died: 1 + 3")


func test_chain_lightning_offers_the_copy_to_the_dead_permanent_s_controller() -> void:
	var owner_seat := Spy.new()
	var thief_seat := Spy.new()
	g.set_agent(0, owner_seat)
	g.set_agent(1, thief_seat)
	var bear := put_battlefield(0, "Grizzly Bears")   # p0 owns it...
	g.change_control(bear, 1)                         # ...p1 controls it
	var bolt := give_hand(0, "Chain Lightning")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 3)
	add_mana(1, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(thief_seat.asked.size(), 1, "that permanent's controller is asked")
	assert_eq(owner_seat.asked.size(), 0)


# --------------------------------------------- H. suspected, confirmed --

func test_axelrod_s_life_goes_to_the_trigger_s_controller() -> void:
	var axelrod := put_battlefield(0, "Axelrod Gunnarson")   # p0 owns him...
	g.change_control(axelrod, 1)                             # ...p1 has him
	var wurm := put_battlefield(0, "Craw Wurm")              # 6/4
	advance_to_next_turn()                                   # p1's turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [axelrod.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {wurm.id: axelrod.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(axelrod.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.stack.size(), 1, "the Wurm's death reaches Axelrod's trigger")
	var shot: int = g.stack.back().targets[0].player_id
	var p0 := g.players[0].life
	var p1 := g.players[1].life
	resolve_stack()
	assert_eq(g.players[1].life, p1 + 1 - (1 if shot == 1 else 0),
		"'you' is the trigger's controller, not Axelrod's owner")
	assert_eq(g.players[0].life, p0 - (1 if shot == 0 else 0))


## The heuristic seat shoots the trigger controller's OPPONENT: a stolen
## Axelrod that died in the same wave has his owner's controller_id back,
## and the ranking used to read that — p1 shot p1 (bug pass 2026-10-03,
## MtgGame.controller_acting_for answers while a trigger's targets are
## ranked).
func test_a_stolen_axelrod_that_died_still_shoots_his_controllers_opponent() -> void:
	var axelrod := put_battlefield(0, "Axelrod Gunnarson")   # p0 owns him...
	g.change_control(axelrod, 1)                             # ...p1 has him
	var wurm := put_battlefield(0, "Craw Wurm")              # 6/4
	advance_to_next_turn()                                   # p1's turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [axelrod.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {wurm.id: axelrod.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(axelrod.zone, Mtg.Zone.GRAVEYARD, "both die in the wave")
	assert_eq(g.stack.size(), 1)
	assert_eq(g.stack.back().targets[0].player_id, 0, "aimed at p1's opponent, not at p1")


func test_infinite_authority_rewards_even_after_the_aura_left() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Wood")
	var aura := give_hand(0, "Infinite Authority")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "destroyed at end of combat")
	g.destroy(aura)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1,
		"the delayed trigger does not need the Aura")


func test_infinite_authority_aura_gone_before_its_trigger_resolves() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Wood")
	var aura := give_hand(0, "Infinite Authority")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	assert_false(g.stack.is_empty(), "the block trigger is waiting")
	g.destroy(aura)
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "CR 603.6: it resolved without the Aura")


func test_ydwen_efreet_that_loses_the_flip_cannot_block_this_turn() -> void:
	var efreet := put_battlefield(1, "Ydwen Efreet")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {efreet.id: bear.id}))
	# Seed the next flip to a LOSS (an odd draw), without spending it.
	var state: int = g.rng.state
	while g.rng.randi() % 2 == 0:
		state = g.rng.state
	g.rng.state = state
	resolve_stack()
	assert_false(g.combat.blocks.has(efreet.id), "the flip was lost")
	assert_true(efreet.cur_cant_block_filter.is_valid(), "and it can't block this turn")
	assert_true(bool(efreet.cur_cant_block_filter.call(bear)))
	advance_to_next_turn()
	assert_false(efreet.cur_cant_block_filter.is_valid(), "only this turn")


func test_gem_bazaar_colour_query_is_side_effect_free() -> void:
	var bazaar := put_battlefield(0, "Gem Bazaar")   # its ETB is waiting
	assert_false(bazaar.memory.has("color"))
	var state: int = g.rng.state
	g.can_afford_cost(0, ManaCost.parse("{1}"))       # the planner asks
	assert_eq(g.rng.state, state, "a query must not consume the RNG")
	assert_false(bazaar.memory.has("color"), "nor choose a colour")
	resolve_stack()
	assert_true(bazaar.memory.has("color"), "the ETB chooses it")
