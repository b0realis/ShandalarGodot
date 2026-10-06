extends GameTest
## REDIRECTION, SHIELDS AND COMBAT ORDERS, READ BY THE FAIR AI (Pack 9;
## [member AiProfile.forecasts_tactics]; engine/ai/tempest_tactics.gd).
##
## The moments the Tempest module answers from the response window, each
## through the role its card module declares:
##  * `redirect_point_to_own` — the en-Kor moves the burn that would kill
##    it, a point an activation, onto our creature that lives through it;
##  * `retarget_from_self` — Silver Wyvern hands their Terror to one of
##    their own creatures;
##  * `source_shield` — Samite Blessing's granted shield on our creature
##    their Lightning Bolt would kill;
##  * `combat_damage_to_creature` — unblocked Soltari Guerrillas put their
##    damage into a creature worth more than the points to the face;
##  * `stash_own_creature` / `release_stash` — Cold Storage hides our
##    creature from their removal and returns it at their end step;
##  * `lure_target` — Trumpeting Armodon orders the creature it kills into
##    its block; a -1/-1 on a blocker (Rabid Rats) kills the blocker that
##    would have lived;
##  * `forces_attacks` — Maddening Imp dooms their summoning-sick team.
## Each has its null arm; the opponent's hidden hand does not move one.


func before_each() -> void:
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


func _lands(name: String, n: int, seat := 0) -> void:
	for _i in n: put_battlefield(seat, name)


func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


func _they_cast_at(spell: String, target: CardInstance, colours: Array) -> CardInstance:
	_their_main()
	var card := give_hand(1, spell)
	for c in colours: add_mana(1, c)
	assert_ok(g.cast_spell(1, card, [TargetRef.card(target)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return card


func _answer_until_resolved(ai: AiPlayer) -> Array:
	var lines: Array = []
	var guard := 0
	while not g.stack.is_empty() and guard < 40:
		if g.priority_player == 0:
			lines.append(ai.act(g))
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	return lines


## Seat 0 declares [param ids]; seat 0 then holds priority before blocks.
func _we_attack(ids: Array) -> void:
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var guard := 0
	while not g.awaiting_attackers and guard < 50:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_attackers(0, ids))


## After [method _we_attack]: seat 1 blocks with [param map]; seat 0 holds
## priority in the declare-blockers step.
func _they_block(map: Dictionary) -> void:
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(1, map))
	guard = 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.DECLARE_BLOCKERS)


# ------------------------------------------------------------- the en-Kor --

func test_the_en_kor_moves_a_bolt_onto_a_creature_that_lives() -> void:
	var ai := _ai()
	var nomads := put_battlefield(0, "Nomads en-Kor")   # 1/1
	var wurm := put_battlefield(0, "Craw Wurm")   # 6/4: lives through 3
	_they_cast_at("Lightning Bolt", nomads, [Mtg.ManaColor.R])
	var lines := _answer_until_resolved(ai)
	assert_string_contains(str(lines), "Nomads en-Kor")
	assert_eq(nomads.zone, Mtg.Zone.BATTLEFIELD, "three points went to the Wurm: %s" % [lines])
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.damage, 3)


func test_no_redirect_that_cannot_save_the_en_kor() -> void:
	var ai := _ai()
	var nomads := put_battlefield(0, "Nomads en-Kor")
	var giant := put_battlefield(0, "Hill Giant")   # 3/3: takes 2 and lives
	_they_cast_at("Lightning Bolt", nomads, [Mtg.ManaColor.R])
	var lines := _answer_until_resolved(ai)
	assert_false(str(lines).contains("Nomads en-Kor"), "two points of three save nothing")
	assert_eq(giant.damage, 0)


func test_the_null_arm_lets_the_en_kor_die() -> void:
	var ai := _ai(false)
	var nomads := put_battlefield(0, "Nomads en-Kor")
	put_battlefield(0, "Craw Wurm")
	_they_cast_at("Lightning Bolt", nomads, [Mtg.ManaColor.R])
	_answer_until_resolved(ai)
	assert_eq(nomads.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------ the Wyvern --

func test_silver_wyvern_hands_their_terror_to_their_own_creature() -> void:
	var ai := _ai()
	var wyvern := put_battlefield(0, "Silver Wyvern")
	_lands("Island", 1)
	var angel := put_battlefield(1, "Serra Angel")
	_they_cast_at("Terror", wyvern, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	var lines := _answer_until_resolved(ai)
	assert_string_contains(str(lines), "Silver Wyvern")
	assert_eq(wyvern.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------ the Samite Blessing --

func test_samite_blessing_shields_the_creature_their_bolt_would_kill() -> void:
	var ai := _ai()
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Grizzly Bears")
	g.attach_aura_from_anywhere(give_hand(0, "Samite Blessing"), giant, 0)
	g.recalculate()
	_they_cast_at("Lightning Bolt", giant, [Mtg.ManaColor.R])
	var lines := _answer_until_resolved(ai)
	assert_string_contains(str(lines), "Hill Giant")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "prevented: %s" % [lines])


# --------------------------------------------------------- the Guerrillas --

func test_unblocked_guerrillas_shoot_their_angel_instead_of_the_face() -> void:
	var ai := _ai()
	var guerrillas := put_battlefield(0, "Soltari Guerrillas")   # 3/2 shadow
	var bears := put_battlefield(1, "Grizzly Bears")
	_we_attack([guerrillas.id])
	_they_block({})
	assert_string_contains(ai.act(g), "Soltari Guerrillas")
	_answer_until_resolved(ai)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20)


func test_the_guerrillas_go_face_for_the_kill() -> void:
	var ai := _ai()
	var guerrillas := put_battlefield(0, "Soltari Guerrillas")
	put_battlefield(1, "Grizzly Bears")
	g.players[1].life = 3
	_we_attack([guerrillas.id])
	_they_block({})
	assert_false(ai.act(g).contains("Soltari Guerrillas"))


# --------------------------------------------------------- Cold Storage --

func test_cold_storage_hides_the_angel_and_brings_it_back() -> void:
	var ai := _ai()
	put_battlefield(0, "Cold Storage")
	_lands("Plains", 3)
	var angel := put_battlefield(0, "Serra Angel")
	_they_cast_at("Swords to Plowshares", angel, [Mtg.ManaColor.W])
	var lines := _answer_until_resolved(ai)
	assert_string_contains(str(lines), "Cold Storage")
	assert_eq(angel.zone, Mtg.Zone.EXILE)
	var guard := 0
	while not (g.current_step() == Mtg.Step.END and g.priority_player == 0) and guard < 60:
		_advance_once()
		guard += 1
	assert_string_contains(ai.act(g), "Cold Storage")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD, "back under our control")
	assert_eq(angel.controller_id, 0)


func test_the_null_arm_lets_the_angel_go() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Cold Storage")
	_lands("Plains", 3)
	var angel := put_battlefield(0, "Serra Angel")
	_they_cast_at("Swords to Plowshares", angel, [Mtg.ManaColor.W])
	_answer_until_resolved(ai)
	assert_ne(angel.data.card_name, "")
	assert_false(angel.memory.has("cold_storage"))


# ------------------------------------------------------- combat orders --

func test_the_armodon_orders_the_bear_into_its_block() -> void:
	var ai := _ai()
	var armodon := put_battlefield(0, "Trumpeting Armodon")   # 3/3
	_lands("Forest", 2)
	var bears := put_battlefield(1, "Grizzly Bears")
	_we_attack([armodon.id])
	assert_string_contains(ai.act(g), "Trumpeting Armodon")
	resolve_stack()
	assert_true(armodon.cur_must_be_blocked, "the bear blocks it this turn if able")
	assert_true(armodon.cur_must_be_blocked_filter.call(bears))


func test_rabid_rats_shrink_the_blocker_that_would_have_lived() -> void:
	var ai := _ai()
	put_battlefield(0, "Rabid Rats")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_we_attack([bears.id])
	_they_block({giant.id: bears.id})
	assert_string_contains(ai.act(g), "Rabid Rats")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the Bears' 2 damage on a Giant shrunk to 2/2")


func test_the_maddening_imp_dooms_their_fresh_creatures() -> void:
	var ai := _ai()
	put_battlefield(0, "Maddening Imp")
	_their_main()
	for _i in 2: put_battlefield(1, "Serra Angel", true)   # just cast: summoning sick
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	assert_string_contains(ai.act(g), "Maddening Imp")


func test_the_null_arm_never_maddens() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Maddening Imp")
	_their_main()
	for _i in 2: put_battlefield(1, "Serra Angel", true)
	assert_ok(g.pass_priority(1))
	assert_false(ai.act(g).contains("Maddening Imp"))


func test_the_en_kor_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		var nomads := put_battlefield(0, "Nomads en-Kor")
		put_battlefield(0, "Craw Wurm")
		give_hand(1, "Terror" if variant == 0 else "Giant Growth")
		g.players[1].library.reverse()
		_they_cast_at("Lightning Bolt", nomads, [Mtg.ManaColor.R])
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
