extends GameTest
## THE PACK 9 BUG PASS, fix-ai-2 — the fair AI's combat readings of the
## Tempest block ([member AiProfile.forecasts_tactics]):
##  * h1-2: the ambush reader (mirage_tactics.gd `_ambush_read`) knows
##    SHADOW both ways (CR 702.28b) — no Tidal Wave Wall or King Cheetah is
##    cast as a "surprise blocker" for a shade, and a flash creature does
##    not wait for an ambush of one;
##  * h1-3: a creature buying ITSELF shadow (`self_keyword`,
##    alliances_tactics.gd) is priced on the exchange — never into a board
##    whose only blockers are shades, which the grant lets block it;
##  * h1-4: Soltari Guerrillas never redirect away a combat that is lethal
##    as declared (tempest_tactics.gd `guerrilla_redirect`);
##  * h1-7: Trumpeting Armodon orders a creature into the block once
##    (tempest_tactics.gd `lure_option`).
## Each has a null arm (gate off) and, where a hidden zone could matter, the
## opponent's hand and library permuted (docs/fair-play.md).

const M := preload("res://engine/ai/mirage_tactics.gd")
const AT := preload("res://engine/ai/alliances_tactics.gd")
const TT := preload("res://engine/ai/tempest_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-9", true)
	super()


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


func _lands(pid: int, card_name: String, n: int) -> void:
	for _i in n: put_battlefield(pid, card_name)


## Seat 1 attacks with [param ids]; seat 0 then holds priority before blocks.
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


## Seat 0 declares [param ids] and holds priority before blocks.
func _we_attack(ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids))
	var guard := 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1


# ------------------------------------------------- h1-2: the ambush and shadow --

func test_tidal_wave_is_not_a_surprise_blocker_for_a_shade() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	var wave := give_hand(0, "Tidal Wave")
	var shade := put_battlefield(1, "Dauthi Marauder")
	assert_true(shade.has_keyword(Mtg.Keyword.SHADOW))
	_they_attack([shade.id])
	var line := ai.act(g)
	assert_false(line.contains("Tidal Wave"), "a Wall without shadow cannot block a shade: %s" % line)
	assert_eq(wave.zone, Mtg.Zone.HAND)


func test_tidal_wave_still_ambushes_a_hill_giant() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	give_hand(0, "Tidal Wave")
	var giant := put_battlefield(1, "Hill Giant")
	_they_attack([giant.id])
	assert_string_contains(ai.act(g), "Tidal Wave")


func test_king_cheetah_is_not_a_surprise_blocker_for_a_shade() -> void:
	var ai := _ai()
	_lands(0, "Forest", 4)
	give_hand(0, "King Cheetah")
	var shade := put_battlefield(1, "Soltari Foot Soldier")
	_they_attack([shade.id])
	var line := M.flash_ambush(g, ai)
	assert_false(line.contains("surprise blocker"), "King Cheetah cannot block a shade: %s" % line)


func test_a_flash_creature_does_not_wait_for_a_shade_it_cannot_block() -> void:
	var ai := _ai()
	_lands(0, "Forest", 4)
	var cheetah := give_hand(0, "King Cheetah")
	put_battlefield(1, "Soltari Foot Soldier")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(M.flash_creature_waits(g, ai, cheetah),
		"the only creature over there is a shade the Cheetah could never block")


func test_the_ambush_reader_reads_shadow_both_ways() -> void:
	var shade := put_battlefield(1, "Soltari Foot Soldier")
	var giant := put_battlefield(1, "Hill Giant")
	var dryad := CardRegistry.get_card("Heartwood Dryad")
	var monk := CardRegistry.get_card("Soltari Monk")
	var bears := CardRegistry.get_card("Grizzly Bears")
	assert_false(bool(M._ambush_read(bears, shade)["blocks"]), "no shadow: can't block a shade")
	assert_true(bool(M._ambush_read(monk, shade)["blocks"]), "a shade blocks a shade")
	assert_true(bool(M._ambush_read(dryad, shade)["blocks"]), "as though it had shadow")
	assert_false(bool(M._ambush_read(monk, giant)["blocks"]), "a shade blocks only shades")
	assert_true(bool(M._ambush_read(dryad, giant)["blocks"]), "the Dryad still blocks normally")


func test_the_null_arm_never_casts_tidal_wave_at_their_attack() -> void:
	var ai := _ai(false)
	_lands(0, "Island", 3)
	var wave := give_hand(0, "Tidal Wave")
	var shade := put_battlefield(1, "Dauthi Marauder")
	_they_attack([shade.id])
	ai.act(g)
	assert_eq(wave.zone, Mtg.Zone.HAND, "the gate-off pilot has no ambush reading")


func test_the_ambush_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_lands(0, "Island", 3)
		give_hand(0, "Tidal Wave")
		var shade := put_battlefield(1, "Dauthi Marauder")
		give_hand(1, "Giant Growth" if variant == 0 else "Unsummon")
		if variant == 1: g.players[1].library.reverse()
		_they_attack([shade.id])
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1], "hidden cards changed the answer")


# ---------------------------------------------- h1-3: buying shadow for itself --

func test_the_emissary_does_not_buy_shadow_into_a_board_of_shades() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	var emissary := put_battlefield(0, "Soltari Emissary")
	var monk := put_battlefield(1, "Soltari Monk")
	_we_attack([emissary.id])
	assert_ne(CombatState.block_illegality(g, monk, emissary, 1), "", "the Monk can't block it now")
	var read: Variant = AT.option(g, ai, emissary, 0, "RESPONSE")
	assert_true(read == null or (read as Dictionary).is_empty(),
		"shadow only lets the Monk block the Emissary; reading was %s" % str(read))
	for _i in 4:
		if g.priority_player != 0 or not g.stack.is_empty(): break
		var line := ai.act(g)
		if line == "" or line == "pass": break
	resolve_stack()
	assert_false(emissary.has_keyword(Mtg.Keyword.SHADOW), "paid {W} to be blockable by the Monk")


func test_the_emissary_does_not_buy_shadow_with_nothing_to_escape() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	var emissary := put_battlefield(0, "Soltari Emissary")
	_we_attack([emissary.id])
	var read: Variant = AT.option(g, ai, emissary, 0, "RESPONSE")
	assert_true(read == null or (read as Dictionary).is_empty(), "nothing over there blocks: %s" % str(read))


func test_the_emissary_buys_shadow_past_a_blocker_without_it() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	var emissary := put_battlefield(0, "Soltari Emissary")
	put_battlefield(1, "Wall of Stone")
	_we_attack([emissary.id])
	var read: Variant = AT.option(g, ai, emissary, 0, "RESPONSE")
	assert_true(read is Dictionary and not (read as Dictionary).is_empty()
		and float(read["value"]) > 0.0, "the Wall stops it; shadow does not: %s" % str(read))


func test_the_null_arm_has_no_self_keyword_reading() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Plains")
	var emissary := put_battlefield(0, "Soltari Emissary")
	put_battlefield(1, "Soltari Monk")
	_we_attack([emissary.id])
	assert_null(AT.option(g, ai, emissary, 0, "RESPONSE"))


# ------------------------------------------------ h1-4: the Guerrillas' redirect --

func _lethal_shades() -> CardInstance:
	var guerrillas := put_battlefield(0, "Soltari Guerrillas")
	var ids := [guerrillas.id]
	for card_name in ["Dauthi Marauder", "Dauthi Slayer", "Soltari Monk"]:
		ids.append(put_battlefield(0, card_name).id)
	for card_name in ["Royal Assassin", "Prodigal Sorcerer", "Hypnotic Specter", "Serra Angel"]:
		put_battlefield(1, card_name)
	g.players[1].life = 10
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var total := 0
	for id in ids: total += g.find_instance(id).cur_power
	assert_eq(total, 10, "the shades together are exactly lethal")
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	var guard := 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	return guerrillas


func test_the_guerrillas_never_redirect_away_a_lethal_attack() -> void:
	var ai := _ai()
	_lethal_shades()
	assert_eq(TT.guerrilla_redirect(g, ai), "", "four unblocked shades deal exactly the 10 life left")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_true(g.game_over and g.winner == 0, "the opponent should be dead (life %d)" % g.players[1].life)


func test_the_guerrillas_still_redirect_when_the_attack_is_not_lethal() -> void:
	var ai := _ai()
	var guerrillas := put_battlefield(0, "Soltari Guerrillas")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [guerrillas.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	var guard := 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_string_contains(TT.guerrilla_redirect(g, ai), "Grizzly Bears",
		"three to their Bears at 20 life is the better use (the control)")


func test_the_null_arm_keeps_the_lethal_damage_on_the_face() -> void:
	var ai := _ai(false)
	_lethal_shades()
	var line := ai.act(g)
	assert_false(line.contains("its combat damage goes to"), line)


# ------------------------------------------------------- h1-7: the Armodon's order --

func _armodon_attack(ai: AiPlayer) -> Array:
	for _i in 6: put_battlefield(0, "Forest")
	var armodon := put_battlefield(0, "Trumpeting Armodon")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [armodon.id]))
	var activations := 0
	var guard := 0
	while g.current_step() == Mtg.Step.DECLARE_ATTACKERS and not g.game_over and guard < 20:
		guard += 1
		if g.priority_player == 0:
			var line := ai.act(g)
			if line.contains("Trumpeting Armodon"): activations += 1
			if line == "" or line == "pass":
				if g.priority_player == 0: assert_ok(g.pass_priority(0))
		else:
			assert_ok(g.pass_priority(1))
	return [armodon, activations]


func test_the_armodon_orders_one_block_once() -> void:
	var ai := _ai()
	var out := _armodon_attack(ai)
	var armodon: CardInstance = out[0]
	assert_true(armodon.cur_must_be_blocked, "the AI ordered the Bears onto the Armodon")
	assert_eq(int(out[1]), 1, "one order is all the Bears can obey")


func test_the_null_arm_never_orders_the_block() -> void:
	var ai := _ai(false)
	var out := _armodon_attack(ai)
	assert_eq(int(out[1]), 0)


func test_the_order_is_read_off_the_live_requirement() -> void:
	var armodon := put_battlefield(0, "Trumpeting Armodon")
	var bears := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	assert_false(TT.already_lured(armodon, bears))
	armodon.cur_must_be_blocked = true
	armodon.cur_must_be_blocked_filter = func(b: CardInstance) -> bool: return b == bears
	assert_true(TT.already_lured(armodon, bears))
	assert_false(TT.already_lured(armodon, wall), "a narrowed order binds only its creature")
	armodon.cur_must_be_blocked_filter = Callable()
	assert_true(TT.already_lured(armodon, wall), "a plain Lure binds every creature")
