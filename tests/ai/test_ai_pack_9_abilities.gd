extends GameTest
## THE TEMPEST BLOCK'S ACTIVATED ABILITIES, READ BY THE FAIR AI (Pack 9;
## [member AiProfile.forecasts_tactics]; engine/ai/tempest_tactics.gd).
##
## Each card module declares a role on the effect its ability carries
## ([member EffectBase.ai_role]); the Tempest module reads the role, never
## the name:
##  * `keeper_condition` — the Keepers: never paid for while no opponent
##    meets the "choose target opponent who …" condition (the engine would
##    refuse the activation after the mana); used when one does;
##  * `destroy_donates_self` — Starke of Rath: removal that hands Starke to
##    the victim's controller is no trade for a Grizzly Bears;
##  * `named_reveal_damage` — Cursed Scroll: the hit chance is the share of
##    our hand the most common name holds;
##  * `bounty_mark` — Bounty Hunter marks at their end step, the shared
##    removal arm collects on our turn;
##  * `land_from_hand`, `charge_counter` / `cash_counters_life`,
##    `cash_counters_damage`, `steal_while_tapped`, `steal_while_enchanted`,
##    `donate_self`, `ping_and_force_attack` — Skyshroud Ranger, Essence
##    Bottle, Torture Chamber, Helm of Possession, Rootwater Matriarch,
##    Jinxed Idol, Bullwhip.
## Each has its null arm (gate off: the pilot as before Pack 9); the
## opponent's hidden hand and library do not move a decision.


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _lands(name: String, n: int, seat := 0) -> void:
	for _i in n: put_battlefield(seat, name)


func _to_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card


## Their end step, seat 0 holding priority, the stack empty.
func _their_end_step() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.END \
			and g.priority_player == 0 and g.stack.is_empty()) and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.END)


## Act for seat 0 until [param needle] appears in a line or it passes.
func _act_until(ai: AiPlayer, needle: String) -> String:
	for _i in 6:
		var line := ai.act(g)
		if line.contains(needle) or line == "pass":
			return line
		resolve_stack()
	return ""


func _first_token(pid: int) -> CardInstance:
	for inst in g.players[pid].battlefield:
		if inst.is_token:
			return inst
	return null


# ------------------------------------------------------------ the Keepers --

func test_keeper_of_the_beasts_is_not_paid_for_without_its_condition() -> void:
	var ai := _ai()
	put_battlefield(0, "Keeper of the Beasts")
	_lands("Forest", 1)
	put_battlefield(1, "Grizzly Bears")   # one each: not "more creatures than you"
	assert_eq(ai.act(g), "pass")
	assert_eq(g.players[0].mana_pool.total(), 0, "no mana spent on a refused activation")


func test_keeper_of_the_beasts_makes_a_beast_when_they_have_more() -> void:
	var ai := _ai()
	put_battlefield(0, "Keeper of the Beasts")
	_lands("Forest", 1)
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	assert_eq(ai.act(g), "activated Keeper of the Beasts")
	resolve_stack()
	assert_not_null(_first_token(0))


func test_keeper_of_the_dead_destroys_their_best_nonblack_creature() -> void:
	var ai := _ai()
	put_battlefield(0, "Keeper of the Dead")
	_lands("Swamp", 1)
	_to_graveyard(0, "Grizzly Bears")
	_to_graveyard(0, "Craw Wurm")
	var angel := put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	assert_eq(ai.act(g), "activated Keeper of the Dead")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)


func test_the_null_arm_keeps_the_keeper_quiet() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Keeper of the Dead")
	_lands("Swamp", 1)
	_to_graveyard(0, "Grizzly Bears")
	_to_graveyard(0, "Craw Wurm")
	var angel := put_battlefield(1, "Serra Angel")
	ai.act(g)
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------- Starke of Rath --

func test_starke_is_not_traded_for_a_bear() -> void:
	var ai := _ai()
	var starke := put_battlefield(0, "Starke of Rath")
	put_battlefield(1, "Grizzly Bears")
	assert_ne(ai.act(g), "activated Starke of Rath")
	assert_eq(starke.controller_id, 0)


func test_the_null_arm_gives_starke_away() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Starke of Rath")
	put_battlefield(1, "Grizzly Bears")
	assert_eq(ai.act(g), "activated Starke of Rath", "the unpriced removal reading (pre-Pack-9 pilot)")


# ----------------------------------------------------------- Cursed Scroll --

func test_the_scroll_with_one_card_in_hand_kills_the_elves() -> void:
	var ai := _ai()
	put_battlefield(0, "Cursed Scroll")
	_lands("Mountain", 3)
	give_hand(0, "Lightning Bolt")
	var elves := put_battlefield(1, "Llanowar Elves")
	_their_end_step()
	assert_string_contains(ai.act(g), "Cursed Scroll")
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD, "one card in hand: the name always matches")


func test_the_scroll_is_a_long_shot_with_a_full_hand() -> void:
	var ai := _ai()
	put_battlefield(0, "Cursed Scroll")
	_lands("Mountain", 3)
	for name in ["Lightning Bolt", "Grizzly Bears", "Giant Growth", "Shock"]:
		give_hand(0, name)
	put_battlefield(1, "Llanowar Elves")
	var option: Dictionary = ai._ability_option(g, g.players[0].battlefield[0], 0, AiPlayer.Moment.MAIN)
	assert_true(option.is_empty() or float(option["value"]) < AiPlayer.ABILITY_BAR_MAIN,
		"a one-in-four shot is no main-phase play: %s" % option)


# ------------------------------------------------------------ Bounty Hunter --

func test_bounty_hunter_marks_at_their_end_step_and_collects_on_our_turn() -> void:
	var ai := _ai()
	put_battlefield(0, "Bounty Hunter")
	var angel := put_battlefield(1, "Serra Angel")
	_their_end_step()
	assert_string_contains(ai.act(g), "Bounty Hunter")
	resolve_stack()
	assert_eq(int(angel.counters.get("bounty", 0)), 1)
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_string_contains(_act_until(ai, "Bounty Hunter"), "Bounty Hunter")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)


func test_the_null_arm_never_marks() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Bounty Hunter")
	var angel := put_battlefield(1, "Serra Angel")
	_their_end_step()
	ai.act(g)
	resolve_stack()
	assert_eq(int(angel.counters.get("bounty", 0)), 0)


# --------------------------------------------------------- Skyshroud Ranger --

func test_the_ranger_puts_a_second_land_after_the_drop() -> void:
	var ai := _ai()
	put_battlefield(0, "Skyshroud Ranger")
	give_hand(0, "Forest")
	give_hand(0, "Forest")
	assert_eq(ai.act(g), "played a land")
	assert_eq(ai.act(g), "activated Skyshroud Ranger")
	resolve_stack()
	var lands := 0
	for p in g.players[0].battlefield:
		if p.is_land(): lands += 1
	assert_eq(lands, 2)


# ------------------------------------------------- Essence Bottle, Chamber --

func test_the_bottle_fills_at_their_end_step_and_is_drunk_at_low_life() -> void:
	var ai := _ai()
	var bottle := put_battlefield(0, "Essence Bottle")
	_lands("Plains", 3)
	_their_end_step()
	assert_string_contains(ai.act(g), "Essence Bottle")
	resolve_stack()
	assert_eq(int(bottle.counters.get("elixir", 0)), 1)
	bottle.counters["elixir"] = 3
	g.players[0].life = 5
	advance_to_next_turn()
	assert_string_contains(_act_until(ai, "Essence Bottle"), "Essence Bottle")
	resolve_stack()
	assert_eq(g.players[0].life, 11)


func test_the_torture_chamber_racks_the_creature_its_counters_kill() -> void:
	var ai := _ai()
	var chamber := put_battlefield(0, "Torture Chamber")
	chamber.counters["pain"] = 2
	_lands("Swamp", 1)
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_string_contains(ai.act(g), "Torture Chamber")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(int(chamber.counters.get("pain", 0)), 0)


# ------------------------------------------------------------------ steals --

func test_the_helm_takes_their_angel_for_our_worst_creature() -> void:
	var ai := _ai()
	put_battlefield(0, "Helm of Possession")
	var elves := put_battlefield(0, "Llanowar Elves")
	_lands("Swamp", 2)
	var angel := put_battlefield(1, "Serra Angel")
	assert_eq(ai.act(g), "activated Helm of Possession")
	resolve_stack()
	assert_eq(angel.controller_id, 0)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


func test_the_matriarch_takes_an_enchanted_creature() -> void:
	var ai := _ai()
	put_battlefield(0, "Rootwater Matriarch")
	var angel := put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Craw Wurm")
	g.attach_aura_from_anywhere(give_hand(1, "Holy Strength"), angel, 1)
	g.recalculate()
	assert_eq(ai.act(g), "activated Rootwater Matriarch")
	resolve_stack()
	assert_eq(angel.controller_id, 0)


func test_the_null_arm_never_steals() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Rootwater Matriarch")
	var angel := put_battlefield(1, "Serra Angel")
	g.attach_aura_from_anywhere(give_hand(1, "Holy Strength"), angel, 1)
	g.recalculate()
	ai.act(g)
	resolve_stack()
	assert_eq(angel.controller_id, 1)


# ------------------------------------------------------------ Jinxed Idol --

func test_the_idol_is_handed_over_at_their_end_step() -> void:
	var ai := _ai()
	var idol := put_battlefield(0, "Jinxed Idol")
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Serra Angel")
	assert_ne(ai.act(g), "activated Jinxed Idol", "not in our main phase")
	_their_end_step()
	assert_string_contains(ai.act(g), "Jinxed Idol")
	resolve_stack()
	assert_eq(idol.controller_id, 1)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the cheapest body pays")


func test_the_idol_is_kept_when_they_can_send_it_straight_back() -> void:
	var ai := _ai()
	var idol := put_battlefield(0, "Jinxed Idol")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	_their_end_step()
	assert_false(ai.act(g).contains("Jinxed Idol"), "a body for two life, and back it comes")
	assert_eq(idol.controller_id, 0)


# ----------------------------------------------------------------- Bullwhip --

func test_the_bullwhip_kills_their_elves() -> void:
	var ai := _ai()
	put_battlefield(0, "Bullwhip")
	_lands("Mountain", 2)
	var elves := put_battlefield(1, "Llanowar Elves")
	_their_end_step()
	assert_string_contains(ai.act(g), "Bullwhip")
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------- Magnetic Web --

func test_magnetic_web_marks_our_hammer_then_their_victim() -> void:
	var ai := _ai()
	put_battlefield(0, "Magnetic Web")
	var giant := put_battlefield(0, "Craw Wurm")
	_lands("Plains", 2)
	var bears := put_battlefield(1, "Grizzly Bears")
	_their_end_step()
	assert_string_contains(ai.act(g), "Magnetic Web")
	resolve_stack()
	assert_eq(int(giant.counters.get("magnet", 0)), 1, "our attacker first")
	advance_to_next_turn()
	_their_end_step()
	assert_string_contains(_act_until(ai, "Magnetic Web"), "Magnetic Web")
	resolve_stack()
	assert_eq(int(bears.counters.get("magnet", 0)), 1, "then the creature it eats")


func test_the_null_arm_never_magnetises() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Magnetic Web")
	var giant := put_battlefield(0, "Craw Wurm")
	_lands("Plains", 2)
	put_battlefield(1, "Grizzly Bears")
	_their_end_step()
	ai.act(g)
	resolve_stack()
	assert_eq(int(giant.counters.get("magnet", 0)), 0)


# ----------------------------------------------------------- Hermit Druid --

func test_hermit_druid_digs_a_land_into_an_empty_hand() -> void:
	var ai := _ai()
	put_battlefield(0, "Hermit Druid")
	_lands("Forest", 1)
	assert_eq(ai.act(g), "activated Hermit Druid")
	resolve_stack()
	var lands := 0
	for card in g.players[0].hand:
		if card.data.is_land(): lands += 1
	assert_eq(lands, 1)


func test_hermit_druid_keeps_still_with_a_land_in_hand() -> void:
	var ai := _ai()
	put_battlefield(0, "Hermit Druid")
	_lands("Forest", 1)
	give_hand(0, "Forest")
	give_hand(0, "Forest")
	assert_eq(ai.act(g), "played a land")
	assert_ne(ai.act(g), "activated Hermit Druid")


# ------------------------------------------------------------ Pandemonium --

func test_pandemonium_aims_a_big_entrant_at_the_creature_it_kills() -> void:
	_ai()
	put_battlefield(1, "Pandemonium")
	var angel := put_battlefield(1, "Serra Angel")
	put_battlefield(0, "Craw Wurm")   # 6 power: the Angel is worth more than 6 to the face
	var ref: TargetRef = g.stack.back().targets[0]
	assert_false(ref.is_player)
	assert_eq(ref.instance_id, angel.id)
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)


func test_pandemonium_aims_a_small_entrant_at_the_face() -> void:
	_ai()
	put_battlefield(1, "Pandemonium")
	put_battlefield(1, "Serra Angel")
	put_battlefield(0, "Llanowar Elves")   # 1 power kills nothing over there
	var ref: TargetRef = g.stack.back().targets[0]
	assert_true(ref.is_player and ref.player_id == 1)


# ----------------------------------------------------- hidden information --

func test_the_keeper_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Keeper of the Dead")
		_lands("Swamp", 1)
		_to_graveyard(0, "Grizzly Bears")
		_to_graveyard(0, "Craw Wurm")
		put_battlefield(1, "Serra Angel")
		give_hand(1, "Terror" if variant == 0 else "Giant Growth")
		g.players[1].library.reverse()
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
