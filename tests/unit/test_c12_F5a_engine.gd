extends GameTest
## The bug campaign c12, fixer F5a — the engine core's findings (h3).
##
## h3-1  a spell with no life cost is castable below 0 life (Lich; the
##       1997 rule that checks life at the end of the phase);
## h3-2  the damage forecast keeps an Illusionary Mask creature face down;
## h3-5  a Lace's colour obeys timestamps in layer 5;
## h3-6  Reflect Damage in the 1997 window names a stolen spell's caster;
## h3-8  "whenever ~ deals damage" triggers once per damage event;
## h3-10 the attack tax is paid before the non-mana attack costs;
## h3-11 a token Firestorm Phoenix / Gravebane Zombie follows its own text;
## h3-12 the mana planner re-chooses a Black Lotus's colour;
## h3-16 Sand Golem enters with its counter;
## h3-17 a masked creature phasing in tapped turns face up;
## h3-18 a 20-digit number in a test position is read without an ERROR;
## h3-19 draw_cards announces the cards drawn before the library ran out;
## h3-20 a stopped loop's state trigger is not logged at every check.


## A seat that wants the 1997 damage-prevention window and names the
## sources it is told to.
class Seat extends DecisionAgent:
	var picks: Array[String] = []

	func wants_damage_prevention_window() -> bool:
		return true

	func choose_card(game: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String,
			optional := false, adverse := false, ordered := false) -> CardInstance:
		for wanted in picks:
			for c in candidates:
				if c.data.card_name == wanted:
					return c
		return super(game, pid, candidates, prompt, optional, adverse, ordered)


const PACKS := ["pack-8", "pack-9"]


func before_each() -> void:
	for p in PACKS: CardPacks.set_enabled(p, true)
	CardRegistry.ensure_loaded()
	super.before_each()


func after_each() -> void:
	g = null
	for p in PACKS: CardPacks.set_enabled(p, false)


func _log_has(text: String) -> bool:
	for line in g.log_lines:
		if String(line).contains(text):
			return true
	return false


func _log_count(text: String) -> int:
	var n := 0
	for line in g.log_lines:
		if String(line).contains(text):
			n += 1
	return n


func _log_index(text: String) -> int:
	for i in g.log_lines.size():
		if String(g.log_lines[i]).contains(text):
			return i
	return -1


func _triggers_from(card_name: String) -> int:
	var n := 0
	for item in g.stack:
		if item.kind == Mtg.StackKind.TRIGGER and item.description.begins_with(card_name):
			n += 1
	return n


# ------------------------------------------------- h3-1: life below zero --

func test_h3_1_a_lich_below_zero_life_casts_a_spell_with_no_life_cost() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Lich")
	g.players[0].life = -3
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, bears))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(g.players[0].has_lost)


func test_h3_1_the_1997_player_below_zero_regains_life_before_the_phase_ends() -> void:
	g.rules.set_preset("fifth")
	assert_true(g.rules.life_checked_at_phase_end, "precondition: the 1997 life check")
	advance_to_step(Mtg.Step.MAIN1)
	g.players[0].life = -3
	var stream := give_hand(0, "Stream of Life")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, stream, [TargetRef.player(0)], 5))
	resolve_stack()
	assert_eq(g.players[0].life, 2)
	advance_to_step(Mtg.Step.MAIN2)
	assert_false(g.players[0].has_lost, "back above 0 before the phase ended")


func test_h3_1_a_life_cost_is_still_checked() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Lich")
	g.players[0].life = -3
	var priced := give_synthetic(0, CardData.new("Test Price", "{0}", Mtg.CardType.SORCERY) \
		.with_additional_life(2))
	assert_refused(g.cast_spell(0, priced), "not enough life")


# --------------------------------------------- h3-2: the forecast is fair --

func _masked_blocker(card_name: String) -> Dictionary:
	before_each()
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(0, "Hill Giant")
	var masked := put_battlefield(1, card_name)
	g.turn_face_down(masked)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {masked.id: giant.id}))
	var future := g.forecast_damage(true)
	return {"future": future, "giant": giant, "masked": masked}


func test_h3_2_the_forecast_reads_a_masked_blocker_as_the_public_2_2() -> void:
	var dragon := _masked_blocker("Shivan Dragon")
	var bears := _masked_blocker("Grizzly Bears")
	for row in [dragon, bears]:
		var future: Dictionary = row["future"]
		var masked: CardInstance = row["masked"]
		var giant: CardInstance = row["giant"]
		assert_false(future["alive"].has(masked.id),
			"%s under the mask: the face-down 2/2 dies to the Giant's 3" % masked.data.card_name)
		assert_true(future["alive"].has(giant.id), "and the Giant takes the 2/2's 2")
		assert_true(masked.face_down, "the forecast left it face down")
	assert_eq(dragon["future"]["alive"].has(dragon["masked"].id),
		bears["future"]["alive"].has(bears["masked"].id),
		"the answer does not depend on the hidden card")


func test_h3_2_the_real_damage_still_turns_it_up() -> void:
	var row := _masked_blocker("Shivan Dragon")
	var dragon: CardInstance = row["masked"]
	var giant: CardInstance = row["giant"]
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_false(dragon.face_down, "dealing and being dealt damage turn it up")
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------- h3-5: a Lace in layer 5 order --

func test_h3_5_chaoslace_after_touch_of_darkness_paints_red() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var touch := give_hand(0, "Touch of Darkness")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, touch, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_colors, Mtg.ManaColor.B, "precondition: black until end of turn")
	var lace := give_hand(0, "Chaoslace")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, lace, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_colors, Mtg.ManaColor.R, "the later effect wins (CR 613.7)")
	g.recalculate()
	assert_eq(bear.cur_colors, Mtg.ManaColor.R, "and keeps winning")


func test_h3_5_a_lace_before_touch_of_darkness_still_loses_to_it() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	g.set_color(bear, Mtg.ManaColor.R)
	g.continuous.add_until_eot_color(bear.id, Mtg.ManaColor.B)
	g.recalculate()
	assert_eq(bear.cur_colors, Mtg.ManaColor.B, "the earlier Lace loses")
	advance_to_next_turn()
	assert_eq(bear.cur_colors, Mtg.ManaColor.R, "and is all that is left once the turn ends")


func test_h3_5_chaoslace_after_celestial_dawn_paints_red() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Celestial Dawn")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.recalculate()
	assert_eq(bear.cur_colors, Mtg.ManaColor.W, "precondition: Dawn's white")
	g.set_color(bear, Mtg.ManaColor.R)
	g.recalculate()
	assert_eq(bear.cur_colors, Mtg.ManaColor.R, "the later Lace wins over the Dawn")


func test_h3_5_celestial_dawn_after_a_lace_paints_white() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	g.set_color(bear, Mtg.ManaColor.R)
	put_battlefield(0, "Celestial Dawn")
	g.recalculate()
	assert_eq(bear.cur_colors, Mtg.ManaColor.W, "the later Dawn wins over the Lace")


# ------------------------------- h3-6: the stolen spell's damage reflected --

## P1's [param card_name], exiled and playable by P0 (Grinning Totem).
func _stolen(card_name: String) -> CardInstance:
	var card := _make_instance(1, card_name)
	card.zone = Mtg.Zone.EXILE
	g.players[1].exile.append(card)
	g.grant_exile_play(card, 0)
	return card


func test_h3_6_reflect_damage_in_the_1997_window_answers_the_stolen_bolts_caster() -> void:
	g.rules.damage_prevention_window = true
	var p1 := Seat.new()
	p1.picks = ["Lightning Bolt"]
	g.set_agent(1, p1)
	advance_to_step(Mtg.Step.MAIN1)
	var reflect := give_hand(1, "Reflect Damage")
	var bolt := _stolen("Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))   # the Bolt resolves; its 3 wait in the window
	assert_true(g.awaiting_damage_prevention, "precondition: the window is open")
	assert_eq(bolt.controller_id, 1, "precondition: the card has gone home")
	if g.priority_player == 0:
		assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	add_mana(1, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(1, reflect, []))
	var guard := 0
	while (not g.stack.is_empty() or g.awaiting_damage_prevention or g.awaiting_regeneration) \
			and not g.game_over and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.players[1].life, 20, "the Bolt is kept off P1")
	assert_eq(g.players[0].life, 17, "and dealt to the player who cast it")


# ------------------------------- h3-8: one "deals damage" trigger per event --

func test_h3_8_a_zebra_unicorn_double_blocked_triggers_once_for_all_it_dealt() -> void:
	g.rules.free_damage_assignment = false   # lethal to each in order: two packets
	advance_to_step(Mtg.Step.MAIN1)
	var zebra := put_battlefield(0, "Zebra Unicorn")
	var a := put_battlefield(1, "Birds of Paradise")
	var b := put_battlefield(1, "Birds of Paradise")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [zebra.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: zebra.id, b.id: zebra.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_triggers_from("Zebra Unicorn"), 1, "one damage event, one trigger (CR 603.2c)")
	resolve_stack()
	assert_eq(g.players[0].life, 22, "for the 2 it dealt in all")


func test_h3_8_one_event_per_source_for_a_simultaneous_bracket() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var caliph := put_battlefield(0, "Emberwilde Caliph")
	var angel := put_battlefield(0, "Warrior Angel")
	var x := put_battlefield(1, "Hill Giant")
	var y := put_battlefield(1, "Hill Giant")
	g.begin_simultaneous()
	g.deal_damage(caliph, TargetRef.card(x), 1)
	g.deal_damage(caliph, TargetRef.card(y), 1)
	g.deal_damage(caliph, TargetRef.player(1), 2)
	g.deal_damage(angel, TargetRef.card(x), 1)
	g.deal_damage(angel, TargetRef.player(1), 2)
	g.end_simultaneous()
	assert_eq(_triggers_from("Emberwilde Caliph"), 1)
	assert_eq(_triggers_from("Warrior Angel"), 1)
	resolve_stack()
	assert_eq(g.players[0].life, 20 - 4 + 3, "lost the Caliph's 4, gained the Angel's 3")


func test_h3_8_a_lone_packet_is_its_own_event() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var zebra := put_battlefield(0, "Zebra Unicorn")
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(zebra, TargetRef.card(giant), 2)
	assert_eq(_triggers_from("Zebra Unicorn"), 1)
	resolve_stack()
	assert_eq(g.players[0].life, 22)


# -------------------------------------------- h3-10: the attack tax first --

func test_h3_10_leviathan_under_propaganda_pays_the_tax_with_the_islands_it_sacrifices() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Propaganda")
	var leviathan := put_battlefield(0, "Leviathan")
	leviathan.tapped = false
	var isle_a := put_battlefield(0, "Island")
	var isle_b := put_battlefield(0, "Island")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [leviathan.id]))
	assert_true(_log_has("P0 pays {2}"), "Propaganda's {2} was paid")
	assert_eq(isle_a.zone, Mtg.Zone.GRAVEYARD, "and both Islands went to the Leviathan")
	assert_eq(isle_b.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.combat.attackers.has(leviathan.id))


# ------------------------------- h3-11: a token follows its own replacement --

func test_h3_11_a_token_firestorm_phoenix_never_dies() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Grim Feast")
	var made := g.create_token(0, CardRegistry.get_card("Firestorm Phoenix"))
	assert_eq(made.size(), 1)
	var hand := g.players[0].hand.size()
	g.destroy(made[0])
	assert_eq(_triggers_from("Grim Feast"), 0, "it went to the hand instead: no death to feast on")
	assert_eq(g.players[0].hand.size(), hand, "and ceased to exist there (CR 111.7)")
	resolve_stack()
	assert_eq(g.players[1].life, 20)


func test_h3_11_a_token_gravebane_zombie_never_dies() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Grim Feast")
	var made := g.create_token(0, CardRegistry.get_card("Gravebane Zombie"))
	assert_eq(made.size(), 1)
	var library := g.players[0].library.size()
	g.destroy(made[0])
	assert_eq(_triggers_from("Grim Feast"), 0, "it went to the library instead")
	assert_eq(g.players[0].library.size(), library, "and ceased to exist there")
	assert_true(_log_has("Gravebane Zombie goes on top of its owner's library instead of dying"))
	resolve_stack()
	assert_eq(g.players[1].life, 20)


# ------------------------------------- h3-12: the Lotus chooses its colour --

func test_h3_12_the_planner_lets_black_lotus_make_red_and_the_volcanic_go() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var plateau := put_battlefield(0, "Plateau")
	var volcanic := put_battlefield(0, "Volcanic Island")
	put_battlefield(0, "Black Lotus")
	assert_true(g.try_pay(0, ManaCost.parse("{W}{R}{R}")))
	assert_eq(g.players[0].mana_pool.total(), 1, "one mana left over, not two")
	assert_true(plateau.tapped, "the Plateau paid the {W}")
	assert_false(volcanic.tapped, "the Lotus's three red left the Volcanic Island alone")


func test_h3_12_every_pip_order_floats_one() -> void:
	for text in ["{W}{R}{R}", "{R}{W}{R}", "{R}{R}{W}"]:
		before_each()
		advance_to_step(Mtg.Step.MAIN1)
		put_battlefield(0, "Plateau")
		put_battlefield(0, "Volcanic Island")
		put_battlefield(0, "Black Lotus")
		assert_true(g.try_pay(0, ManaCost.parse(text)), text)
		assert_eq(g.players[0].mana_pool.total(), 1, text)


# ------------------------------------ h3-16: Sand Golem enters with it --

var _entered_with := -1
var _entered_power := -1


func _on_event(event: GameEvent, golem: CardInstance) -> void:
	if event.type == Mtg.EventType.ENTERS_BATTLEFIELD and event.data.get("instance") == golem:
		_entered_with = int(golem.counters.get("+1/+1", 0))
		_entered_power = golem.cur_power


func test_h3_16_sand_golem_enters_with_its_counter() -> void:
	var golem := give_hand(0, "Sand Golem")
	var scepter := put_battlefield(1, "Disrupting Scepter")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, scepter, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD)
	g.event_occurred.connect(_on_event.bind(golem))
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.END) and guard < 400:
		_advance_once()
		guard += 1
	resolve_stack()
	assert_eq(golem.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(_entered_with, 1, "the counter was there as it entered")
	assert_eq(_entered_power, 4, "an enters listener sees a 4/4, never a 3/3")
	assert_eq(int(golem.counters.get("+1/+1", 0)), 1, "one counter, not two")


# ------------------------------- h3-17: a masked creature phasing in tapped --

func test_h3_17_a_masked_creature_phasing_in_tapped_turns_face_up() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	g.turn_face_down(bear)
	assert_true(g.phase_out(bear))
	assert_true(g.phase_in(bear, true))   # Oubliette's "tap that creature as it phases in"
	assert_true(bear.tapped)
	assert_false(bear.face_down, "would become tapped: turned face up instead, and tapped")


func test_h3_17_phasing_in_untapped_leaves_the_mask_on() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	g.turn_face_down(bear)
	assert_true(g.phase_out(bear))
	assert_true(g.phase_in(bear))
	assert_true(bear.face_down)


# ---------------------------------- h3-18: a number too long to be one --

func test_h3_18_a_twenty_digit_number_is_read_without_an_engine_error() -> void:
	var position := DuelPosition.from_dict({
		"lives": ["99999999999999999999", "-99999999999999999999"],
		"random_cards": ["000000000000000000000007", "12345678901234567890123"],
		"active_player": "99999999999999999999",
		"step": "123456789012345678901",
	})
	assert_eq(position.lives[0], DuelPosition.MAX_LIFE, "a huge life is the most a seat may have")
	assert_eq(position.lives[1], 1, "a huge negative one the least")
	assert_eq(position.random_cards[0], 7, "leading zeros are not digits that count")
	assert_eq(position.random_cards[1], DuelPosition.MAX_RANDOM)
	assert_eq(position.active_player, 1)
	assert_eq(position.step, Mtg.Step.MAIN1, "no such step: the default")


# ---------------------------------------------- h3-19: the draws announced --

func test_h3_19_the_card_drawn_before_the_library_ran_out_is_announced_first() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var library := g.players[0].library
	while library.size() > 1:
		library.pop_back()
	var hand := g.players[0].hand.size()
	g.draw_cards(0, 2)
	assert_eq(g.players[0].hand.size(), hand + 1)
	var drew := _log_index("P0 draws a card")
	var tried := _log_index("P0 tries to draw from an empty library")
	assert_gt(drew, -1, "the card that did move is announced")
	assert_gt(tried, drew, "before the draw that could not happen")
	assert_true(g.players[0].has_lost, "and the empty library still loses (CR 704.5b)")


# ------------------------------------- h3-20: a stopped loop stays quiet --

static func _always(_g: MtgGame, _s: CardInstance, _e: GameEvent) -> bool:
	return true


static func _nothing(_g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	pass


func test_h3_20_a_stopped_loops_state_trigger_is_not_logged_at_every_check() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(0, CardData.new("Test Loop", "{0}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(Mtg.EventType.STATE_CHECK, _nothing,
			"Test loop.", _always)))
	g.loop_stopped_by = 0   # SETUP: the loop limit has stopped this step
	var before := _log_count("not put on the stack")
	for _i in 5:
		g.check_state_based_actions()
	assert_eq(_log_count("not put on the stack") - before, 0,
		"nothing goes on the stack after the stop, and nothing is looked for")
	assert_eq(_triggers_from("Test Loop"), 0)
