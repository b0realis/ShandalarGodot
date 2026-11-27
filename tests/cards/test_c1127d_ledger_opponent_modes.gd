extends GameTest
## The fidelity ledger's "An opponent chooses one —" row (Alliances, Pack
## 5), lifted for the mode: Library of Lat-Nam, Misfortune and Fatal Lore
## have their mode chosen by the opponent AS THE SPELL IS CAST (CR 601.2b,
## 700.2), so both players respond knowing it. The choice is a cost-time
## question put to the opponent ([member CardData.opponent_modes]), kept on
## the stack item, and nobody is asked again as the spell resolves.
## (Fatal Lore's creatures are still chosen on resolution — its ledger row.)

const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G
const U := Mtg.ManaColor.U


## Answers the mode question with [member pick]; notes when it was asked.
class ModeSeat extends DecisionAgent:
	var pick := 0
	var asked: Array = []
	var stack_sizes: Array = []
	func answer_option(game: MtgGame, pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		if not prompt.ends_with("— choose"):
			return super(game, pid, prompt, options, hint)
		asked.append(prompt)
		stack_sizes.append(game.stack.size())
		return pick


func before_each() -> void:
	CardPacks.set_enabled("pack-5", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-5", false)


func _seat(pick: int) -> ModeSeat:
	var seat := ModeSeat.new()
	seat.pick = pick
	g.agents[1] = seat
	return seat


func _misfortune() -> CardInstance:
	var spell := give_hand(0, "Misfortune")
	add_mana(0, B); add_mana(0, R); add_mana(0, G); add_mana(0, Mtg.ManaColor.C)
	return spell


func _library() -> CardInstance:
	var spell := give_hand(0, "Library of Lat-Nam")
	add_mana(0, U); add_mana(0, Mtg.ManaColor.C, 4)
	return spell


func test_the_printed_text_carries_no_adaptation_note() -> void:
	for card_name in ["Library of Lat-Nam", "Misfortune"]:
		assert_false(CardRegistry.get_card(card_name).oracle_text.contains("SIMPLIFIED"), card_name)


func test_misfortune_mode_is_chosen_as_it_is_cast() -> void:
	var seat := _seat(1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := _misfortune()
	assert_ok(g.cast_spell(0, spell, []))
	assert_eq(seat.asked.size(), 1, "the opponent chose during the announcement")
	assert_eq(seat.stack_sizes[0], 0, "before the spell was on the stack")
	assert_eq(spell.zone, Mtg.Zone.STACK)
	assert_eq(g.players[1].life, 20, "nothing has happened yet")
	assert_string_contains(g.stack[-1].description, "-1/-1", "the chosen mode is announced")
	# A changed mind does not matter: the mode is locked in.
	seat.pick = 0
	resolve_stack()
	assert_eq(seat.asked.size(), 1, "nobody is asked again on resolution")
	assert_eq(g.players[1].life, 16, "4 damage to the chooser")
	assert_eq(g.players[0].life, 20)
	assert_eq(int(bear.counters.get("-1/-1", 0)), 1, "a -1/-1 counter on each of their creatures")


func test_misfortune_first_mode() -> void:
	_seat(0)
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.cast_spell(0, _misfortune(), []))
	resolve_stack()
	assert_eq(g.players[0].life, 24)
	assert_eq(int(mine.counters.get("+1/+1", 0)), 1)
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20)


func test_library_of_lat_nam_mode_is_chosen_as_it_is_cast() -> void:
	var seat := _seat(0)
	var spell := _library()
	assert_ok(g.cast_spell(0, spell, []))
	assert_eq(seat.asked.size(), 1)
	assert_eq(seat.stack_sizes[0], 0)
	seat.pick = 1
	var hand := g.players[0].hand.size()
	resolve_stack()
	assert_eq(seat.asked.size(), 1)
	assert_eq(g.players[0].hand.size(), hand, "no search: the draw waits for the next upkeep")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.players[0].hand.size(), hand + 3, "three cards at the next turn's upkeep")


func test_library_of_lat_nam_search_mode() -> void:
	_seat(1)
	var hand := g.players[0].hand.size()
	assert_ok(g.cast_spell(0, _library(), []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1, "the Library left the hand, a searched card came")


func test_fatal_lore_mode_is_chosen_as_it_is_cast() -> void:
	var seat := _seat(0)
	put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Fatal Lore")
	add_mana(0, B, 4)
	var hand := g.players[0].hand.size()
	assert_ok(g.cast_spell(0, spell, []))
	assert_eq(seat.asked.size(), 1)
	assert_eq(seat.stack_sizes[0], 0)
	seat.pick = 1
	resolve_stack()
	assert_eq(seat.asked.size(), 1)
	assert_eq(g.players[0].hand.size(), hand - 1 + 3, "the caster draws three")


func test_a_refused_cast_asks_the_opponent_nothing() -> void:
	var seat := _seat(1)
	var spell := give_hand(0, "Misfortune")
	add_mana(0, B)
	assert_refused(g.cast_spell(0, spell, []))
	assert_eq(seat.asked.size(), 0)


func test_a_human_opponent_holds_the_cast_open() -> void:
	var human := HumanAgent.new()
	g.agents[1] = human
	g.interactive_choices = true
	var spell := _misfortune()
	assert_ok(g.cast_spell(0, spell, []))
	assert_not_null(g.awaiting_choice, "the cast waits for the opponent's mode")
	if g.awaiting_choice == null: return
	var question: PlayerChoice = g.awaiting_choice
	assert_eq(question.pid, 1)
	assert_true(question.adverse)
	assert_eq(question.options.size(), 2)
	assert_eq(spell.zone, Mtg.Zone.HAND, "nothing is paid or moved while it waits")
	assert_eq(g.players[0].mana_pool.total(), 4)
	assert_refused(g.cancel_choice(), "must be answered")
	assert_ok(g.answer_choice(1))
	assert_null(g.awaiting_choice)
	assert_eq(spell.zone, Mtg.Zone.STACK)
	assert_eq(g.players[0].mana_pool.total(), 0)
	resolve_stack()
	assert_null(g.awaiting_choice, "no second question on resolution")
	assert_eq(g.players[1].life, 16)


func test_a_copy_keeps_the_chosen_mode() -> void:
	var seat := _seat(1)
	var spell := _misfortune()
	assert_ok(g.cast_spell(0, spell, []))
	g.copy_spell_on_stack(spell, 0)
	seat.pick = 0
	resolve_stack()
	assert_eq(seat.asked.size(), 1, "a copy copies the mode (CR 707.10)")
	assert_eq(g.players[1].life, 12, "both dealt their 4")


## THE COMPUTER CASTS IT AT A PLAYER: the cast waits on the player's mode,
## the computer does nothing else meanwhile (every action is refused while
## the question is open), and the answer puts the spell on the stack once.
func test_the_computers_cast_waits_for_the_players_mode() -> void:
	var profile := AiProfile.wizard()
	profile.develops_late = false
	profile.mistake_chance = 0.0
	var ai := AiPlayer.new(0, profile)
	g.set_agent(0, ai)
	g.agents[1] = HumanAgent.new()
	g.interactive_choices = true
	for land in ["Swamp", "Mountain", "Forest", "Forest"]:
		put_battlefield(0, land)
	var spell := give_hand(0, "Misfortune")
	ai.act(g)
	assert_not_null(g.awaiting_choice, "the computer's cast waits for the mode")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.pid, 1)
	assert_eq(spell.zone, Mtg.Zone.HAND)
	var step := g.current_step()
	var holder: int = g.priority_player
	ai.act(g)
	assert_eq(spell.zone, Mtg.Zone.HAND, "nothing moves while it waits")
	assert_eq(g.current_step(), step)
	assert_eq(g.priority_player, holder)
	assert_true(g.stack.is_empty())
	assert_ok(g.answer_choice(1))
	assert_null(g.awaiting_choice)
	assert_eq(spell.zone, Mtg.Zone.STACK)
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_null(g.awaiting_choice, "no second question on resolution")
	assert_eq(g.players[1].life, 16)
