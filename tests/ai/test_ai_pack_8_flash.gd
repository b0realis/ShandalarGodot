extends GameTest
## FLASH, READ BY THE FAIR AI (Pack 8, 2026-10-03; engine package E3; CR
## 702.8; [member AiProfile.forecasts_tactics] on a seat that holds
## instants).
##
##  * A FLASH CREATURE (the keyword, or any creature [method
##    MtgGame.casts_at_instant_speed] admits — Winding Canyons' grant) is
##    not spent in our own main phase: it waits for their turn — an
##    AMBUSH BLOCKER cast after their attackers are declared when it kills
##    one and lives, or stops the lethal one, and otherwise deployed at
##    their end step, the mana it kept open having threatened all turn.
##  * A FLASH-RIDER AURA cast at instant speed is sacrificed at the next
##    cleanup step (`memory["flash_cast"]`): a ONE-TURN TRICK, cast after
##    blocks where its numbers win the combat; cast in a main phase it is
##    the permanent aura the main planner always priced.
##  * A WARD (protection from the chosen colour, shroud) cast at instant
##    speed in response to a removal spell makes the spell's target illegal.

const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai(profile: AiProfile = null) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _lands(name: String, n: int) -> Array:
	var out: Array = []
	for _i in n: out.append(put_battlefield(0, name))
	return out


func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


func _they_attack(ids: Array) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, ids))
	guard = 0
	while g.priority_player != 0 and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)


## After [method _they_attack]: walk to declare blockers, block with
## [param block_map], and hand seat 0 priority there.
func _we_block(block_map: Dictionary) -> void:
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(0, block_map))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# --------------------------------------------------- the flash creature --

func test_a_flash_creature_waits_for_their_end_step() -> void:
	# Their Llanowar Elves is an attacker the Cheetah would block, kill and
	# survive: the hold has a payoff, and nothing else in hand wants the
	# mana — so the body waits for their turn.
	var ai := _ai()
	_lands("Forest", 4)
	var cheetah := give_hand(0, "King Cheetah")
	put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.MAIN1)
	var said := ai.act(g)
	assert_false(said.contains("King Cheetah"), "not in our main phase: %s" % said)
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "King Cheetah")
	resolve_stack()
	assert_eq(cheetah.zone, Mtg.Zone.BATTLEFIELD)


## THE HOLD MUST PAY FOR ITS TEMPO (the matched Deck Lab study: holding
## every flash creature measured -14.5 +-9.3 against the Costs deck).

func test_a_flash_creature_with_no_ambush_to_wait_for_is_cast_now() -> void:
	var ai := _ai()
	_lands("Forest", 4)
	give_hand(0, "King Cheetah")
	put_battlefield(1, "Grizzly Bears")   # it would trade, not ambush
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast King Cheetah")


func test_a_flash_creature_never_holds_back_another_card() -> void:
	var ai := _ai()
	_lands("Forest", 4)
	var cheetah := give_hand(0, "King Cheetah")
	var bears := give_hand(0, "Grizzly Bears")
	put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.MAIN1)
	var guard := 0
	while guard < 4 and (cheetah.zone == Mtg.Zone.HAND or bears.zone == Mtg.Zone.HAND):
		if ai.act(g) == "pass": break
		resolve_stack()
		guard += 1
	assert_eq(cheetah.zone, Mtg.Zone.BATTLEFIELD, "the Bears wanted mana: no hold")


func test_a_trick_aura_with_no_blocker_to_beat_goes_on_for_keeps() -> void:
	var ai := _ai()
	_lands("Forest", 2)
	var bears := put_battlefield(0, "Grizzly Bears")
	var armor := give_hand(0, "Armor of Thorns")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Armor of Thorns")
	resolve_stack()
	assert_eq(armor.attached_to, bears.id)
	assert_false(bool(armor.memory.get("flash_cast", false)), "a permanent +2/+2")


func test_a_flash_knight_ambushes_their_attacker() -> void:
	var ai := _ai()
	_lands("Plains", 3)
	var knight := give_hand(0, "Benalish Knight")
	var bears := put_battlefield(1, "Grizzly Bears")
	_they_attack([bears.id])
	assert_string_contains(ai.act(g), "Benalish Knight")
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD, "in time to block")
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		if g.priority_player == 0: ai.act(g)
		else: assert_ok(g.pass_priority(1))
		guard += 1
	assert_string_contains(ai.act(g), "block")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "first strike: the Bears never struck back")
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)


func test_null_arm_casts_the_flash_creature_in_the_main_phase() -> void:
	var ai := _ai(_null())
	_lands("Forest", 4)
	give_hand(0, "King Cheetah")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "King Cheetah")


# ------------------------------------------------ the one-turn aura trick --

func test_armor_of_thorns_wins_a_block_and_is_gone_at_cleanup() -> void:
	var ai := _ai()
	_lands("Forest", 2)
	var bears := put_battlefield(0, "Grizzly Bears")
	var armor := give_hand(0, "Armor of Thorns")
	var giant := put_battlefield(1, "Hill Giant")
	_they_attack([giant.id])
	_we_block({bears.id: giant.id})
	assert_string_contains(ai.act(g), "Armor of Thorns")
	resolve_stack()
	assert_eq(armor.attached_to, bears.id)
	assert_true(bool(armor.memory.get("flash_cast", false)), "cast at instant speed: a one-turn trick")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "a 4/4 Bears kills the Giant")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "and lives")
	advance_to_next_turn()
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD, "sacrificed at the cleanup step")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_no_trick_when_it_changes_nothing() -> void:
	var ai := _ai()
	_lands("Forest", 2)
	var bears := put_battlefield(0, "Grizzly Bears")
	var armor := give_hand(0, "Armor of Thorns")
	var brute := put_synthetic(1, CardData.new("Test Brute", "{5}{G}", Mtg.CardType.CREATURE).pt(6, 6))
	_they_attack([brute.id])
	_we_block({bears.id: brute.id})
	ai.act(g)
	assert_eq(armor.zone, Mtg.Zone.HAND, "a 4/4 still dies to a 6/6 and does not kill it")


func test_a_trick_aura_is_free_fodder_once_cast() -> void:
	var ai := _ai()
	var bears := put_battlefield(0, "Grizzly Bears")
	var armor := put_battlefield(0, "Armor of Thorns")
	armor.attached_to = bears.id
	armor.memory["flash_cast"] = true
	assert_eq(ai._own_value(g, armor), 0.0, "it is sacrificed at cleanup anyway")


# --------------------------------------------------------------- the ward --

func _terror_at(victim: CardInstance) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) and guard < 400:
		_advance_once()
		guard += 1
	var terror := give_hand(1, "Terror")
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, terror, [TargetRef.card(victim)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


func test_mystic_veil_answers_a_terror() -> void:
	var ai := _ai()
	_lands("Island", 2)
	var angel := put_battlefield(0, "Serra Angel")
	var veil := give_hand(0, "Mystic Veil")
	_terror_at(angel)
	assert_string_contains(ai.act(g), "Mystic Veil")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD, "shroud: the Terror lost its target")
	assert_eq(veil.attached_to, angel.id)


func test_ward_of_lights_names_the_terror_s_colour() -> void:
	var ai := _ai()
	_lands("Plains", 2)
	var angel := put_battlefield(0, "Serra Angel")
	var ward := give_hand(0, "Ward of Lights")
	_terror_at(angel)
	assert_string_contains(ai.act(g), "Ward of Lights")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD, "protection from black")
	assert_eq(int(ward.memory.get("ward_color", 0)), Mtg.ManaColor.B)


func test_the_ambush_ignores_their_hidden_cards() -> void:
	# The same public board, their hand and library permuted: the answer
	# cannot move.
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_lands("Plains", 3)
		give_hand(0, "Benalish Knight")
		var bears := put_battlefield(1, "Grizzly Bears")
		give_hand(1, "Giant Growth" if variant == 0 else "Terror")
		g.players[1].library.reverse()
		_they_attack([bears.id])
		answers.append(ai.act(g).contains("Benalish Knight"))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
	assert_true(answers[0])


# ------------------------- the trick aura waits for the combat (audit, B) --
#
# The audit: ten flash-rider Auras cast, every one at sorcery speed, never
# as a trick — the main planner cast the aura in our FIRST main phase as a
# permanent pump, so it was never in hand when the blocks came. With a
# combat ahead, the first main phase now leaves it in hand with its mana
# booked; the combat casts it where it wins or saves a fight; the second
# main phase casts what is left for its permanent value.

func test_the_trick_aura_waits_out_the_first_main_phase() -> void:
	var ai := _ai()
	_lands("Forest", 2)
	put_battlefield(0, "Grizzly Bears")
	var armor := give_hand(0, "Armor of Thorns")
	put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	var said := ai.act(g)
	assert_false(said.contains("Armor of Thorns"), "held for the combat: %s" % said)
	assert_eq(armor.zone, Mtg.Zone.HAND)


func test_the_trick_wins_our_attack_and_main_two_keeps_it_permanent() -> void:
	var ai := _ai()
	_lands("Forest", 4)
	var bears := put_battlefield(0, "Grizzly Bears")
	var armor := give_hand(0, "Armor of Thorns")
	var spider := give_hand(0, "Spider Climb")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: bears.id}))
	assert_eq(g.priority_player, 0)
	assert_string_contains(ai.act(g), "combat trick")
	resolve_stack()
	assert_eq(armor.attached_to, bears.id)
	assert_true(bool(armor.memory.get("flash_cast", false)))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_step(Mtg.Step.MAIN2)
	var guard := 0
	while spider.zone == Mtg.Zone.HAND and guard < 3:
		ai.act(g)
		resolve_stack()
		guard += 1
	assert_eq(spider.attached_to, bears.id, "cast in main 2 for keeps")
	assert_false(bool(spider.memory.get("flash_cast", false)))


func test_the_held_trick_sends_one_more_attacker() -> void:
	# A Grizzly Bears into an untapped Hill Giant is no attack — unless the
	# Armor of Thorns in hand makes it a 4/4 after the block, the rider
	# a Giant Growth already gets.
	var ai := _ai()
	_lands("Forest", 2)
	var bears := put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Armor of Thorns")
	put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	assert_true(g.combat.attackers.has(bears.id))
