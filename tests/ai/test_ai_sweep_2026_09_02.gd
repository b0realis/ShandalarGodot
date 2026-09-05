extends GameTest
## The 2026-09-02 AI bug sweep: every finding of the read-only review pinned
## by a test that FAILED before its fix. Combat REQUIREMENTS the AI never
## mirrored (Lure, Nettling Imp, Blaze of Glory, the Caverns of Despair
## caps) and wedged the declare steps for good; a Fallen Angel eating its
## own board because a free sacrifice pump bypassed the ability gate and a
## COST ask picked the MOST valuable body; restricted mana (Mishra's
## Workshop) planned as if it were generic; play bans and hand locks
## ignored by the caster; protection missing from the combat maths;
## colour-blind firebreathing reach; a free untapped ability firing
## forever at the mana sink. Every test acts through AiPlayer.act and the
## public MtgGame API.


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached the opponent's %s" % Mtg.step_name(step))
	assert_eq(g.priority_player, 1, "the active player gets priority first")
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


func _all_untapped(seat: int, land_name: String) -> bool:
	for inst in g.players[seat].battlefield:
		if inst.data.card_name == land_name and inst.tapped:
			return false
	return true


# ------------------------------------ 1. combat requirements (HIGH) --

func test_lured_attacker_gets_every_able_blocker() -> void:
	# Lure on their Bears; our Wall of Wood AND our Savannah Lions must
	# both block it (CR 509.1c). The old AI blocked with the wall alone,
	# was refused, fell back to no blocks, was refused again, and the
	# declare-blockers step never ended.
	var ai := _wizard(1)
	var bears := put_battlefield(0, "Grizzly Bears")
	var lure := give_hand(0, "Lure")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, lure, [TargetRef.card(bears)]))
	resolve_stack()
	var wall := put_battlefield(1, "Wall of Wood")
	var lions := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var did := ai.act(g)
	assert_string_contains(did, "block")
	assert_false(g.awaiting_blockers, "the declaration was accepted")
	assert_eq(int(g.combat.blocks.get(wall.id, -1)), bears.id, "the wall blocks the lure")
	assert_eq(int(g.combat.blocks.get(lions.id, -1)), bears.id, "the lions must too")


func test_nettled_creature_attacks_when_ordered() -> void:
	# Their Nettling Imp orders our Bears into a Craw Wurm. A losing attack
	# the AI would never choose — but "attacks this turn if able" is not
	# a choice, and refusing to declare it wedged the attack step.
	var ai := _wizard(0)
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Craw Wurm")
	var imp := put_battlefield(1, "Nettling Imp")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, imp, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_true(bears.must_attack_this_turn)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var did := ai.act(g)
	assert_string_contains(did, "attacker")
	assert_false(g.awaiting_attackers, "the declaration was accepted")
	assert_true(g.combat.attackers.has(bears.id), "the conscript attacked")


func test_blaze_of_glory_conscript_blocks_every_attacker() -> void:
	# Their Blaze of Glory on our Wall of Stone: it must block EACH
	# attacker it can (CR 509.1b lifted by the same card). The planner
	# gave it one attacker; the engine refused; the step never ended.
	var ai := _wizard(1)
	var bears := put_battlefield(0, "Grizzly Bears")
	var lions := put_battlefield(0, "Savannah Lions")
	var blaze := give_hand(0, "Blaze of Glory")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id, lions.id]))
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, blaze, [TargetRef.card(wall)]))
	resolve_stack()
	assert_true(wall.must_block_this_turn)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	ai.act(g)
	assert_false(g.awaiting_blockers, "the declaration was accepted")
	assert_true(g.combat.blocked_attackers.has(bears.id), "the wall blocks the bears")
	assert_true(g.combat.blocked_attackers.has(lions.id), "... and the lions")


func test_caverns_cap_trims_the_attack_to_two() -> void:
	# Caverns of Despair: no more than two may attack. Three Bears into an
	# empty board used to be refused and replaced by NO attack at all.
	var ai := _wizard(0)
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Caverns of Despair")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_string_contains(ai.act(g), "2 attacker")
	assert_false(g.awaiting_attackers)
	assert_eq(g.combat.attackers.size(), 2)


func test_caverns_cap_with_a_juggernaut_does_not_wedge() -> void:
	# Juggernaut attacks each combat if able; with two Bears beside it and
	# the Caverns' cap of two, the three-creature declaration was refused
	# and the empty fallback was refused too (the Juggernaut can attack) —
	# the wedge the reviewer found. The cap keeps the must-attacker.
	var ai := _wizard(0)
	var jugg := put_battlefield(0, "Juggernaut")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Caverns of Despair")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_false(g.awaiting_attackers, "the declaration was accepted")
	assert_eq(g.combat.attackers.size(), 2)
	assert_true(g.combat.attackers.has(jugg.id), "the must-attacker is among them")


func test_caverns_cap_trims_the_blocks_to_two() -> void:
	# The blocking half of the same card: three walls wanted to block
	# three Bears; the refusal used to leave everything unblocked.
	var ai := _wizard(1)
	var ids: Array = []
	for _i in 3:
		ids.append(put_battlefield(0, "Grizzly Bears").id)
	for _i in 3:
		put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids))
	# The Caverns land after the attack (its attacker cap would have
	# refused three Bears) — only the blocker cap is under test.
	put_battlefield(1, "Caverns of Despair")
	assert_eq(g.max_blockers, 2)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	ai.act(g)
	assert_false(g.awaiting_blockers, "the declaration was accepted")
	assert_eq(g.combat.blocks.size(), 2, "two blockers, the cap")


func test_lure_and_the_cap_together_still_declare() -> void:
	# A lured attacker under the Caverns: the cap excuses the third body
	# (CR 509.1c/508.1d) and the AI must know that too.
	var ai := _wizard(1)
	var bears := put_battlefield(0, "Grizzly Bears")
	var lure := give_hand(0, "Lure")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, lure, [TargetRef.card(bears)]))
	resolve_stack()
	for _i in 3:
		put_battlefield(1, "Savannah Lions")
	put_battlefield(1, "Caverns of Despair")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	ai.act(g)
	assert_false(g.awaiting_blockers, "the declaration was accepted")
	assert_eq(g.combat.blocks.size(), 2, "two lions on the lure, the cap")


# ----------------------------------------- 2. Fallen Angel / Atog (HIGH) --

func test_fallen_angel_does_not_eat_its_own_board_when_unblocked() -> void:
	# Unblocked at twenty life: the free pump's sacrifice rider bypassed
	# the ability gate and the cost ask fed it the Serra, then the Angel.
	var ai := _wizard(0)
	var angel := put_battlefield(0, "Fallen Angel")
	var serra := put_battlefield(0, "Serra Angel")
	var bears := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [angel.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_eq(g.priority_player, 0)
	assert_eq(ai.act(g), "pass")
	assert_eq(serra.zone, Mtg.Zone.BATTLEFIELD, "the Serra lives")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the Bears live")
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)


func test_cost_asks_eat_the_least_valuable_body() -> void:
	# "As an additional cost, sacrifice a creature" (Sacrifice): the seat
	# choosing what its OWN cost eats gives up the cheapest body.
	_wizard(0)
	var serra := put_battlefield(0, "Serra Angel")
	var bears := put_battlefield(0, "Grizzly Bears")
	var spell := give_hand(0, "Sacrifice")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, spell, []))
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the Bears were eaten")
	assert_eq(serra.zone, Mtg.Zone.BATTLEFIELD, "not the Serra")


func test_sacrifice_spell_waits_for_fodder_worth_less_than_itself() -> void:
	# No creature to sacrifice: the cast can only be refused, and the old
	# planner tapped the Swamp for it first.
	var ai := _wizard(0)
	give_hand(0, "Sacrifice")
	put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	assert_true(_all_untapped(0, "Swamp"), "no land was tapped for a refused cast")


# --------------------------------------- 3. Mishra's Workshop (MEDIUM) --

func test_workshop_mana_is_not_planned_for_a_creature() -> void:
	# {C}{C}{C} that only an artifact spell may spend: planned as generic,
	# the Workshop and a Swamp were tapped for a Scathe Zombies the engine
	# then refused, and the mana burned at the end of the step.
	var ai := _wizard(0)
	put_battlefield(0, "Mishra's Workshop")
	_lands(0, "Swamp", 2)
	give_hand(0, "Scathe Zombies")   # {2}{B}
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	assert_true(_all_untapped(0, "Swamp"), "no land tapped for a cast that cannot be paid")
	assert_true(_all_untapped(0, "Mishra's Workshop"))
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing floating to burn")


func test_workshop_mana_casts_an_artifact() -> void:
	var ai := _wizard(0)
	put_battlefield(0, "Mishra's Workshop")
	put_battlefield(0, "Swamp")
	give_hand(0, "Icy Manipulator")   # {4}
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Icy Manipulator")
	resolve_stack()
	assert_not_null(g.find_on_battlefield(0, "Icy Manipulator"))


# ---------------------------------- 4. play bans and hand locks (MEDIUM) --

func test_city_in_a_bottle_ban_keeps_the_lands_untapped() -> void:
	# Erg Raiders is an Arabian Nights name: under the Bottle it cannot be
	# cast, and the old planner tapped both Swamps before finding out.
	var ai := _wizard(0)
	put_battlefield(1, "City in a Bottle")
	give_hand(0, "Erg Raiders")   # {1}{B}
	_lands(0, "Swamp", 2)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	assert_true(_all_untapped(0, "Swamp"))
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_hand_locked_card_is_not_planned() -> void:
	# A Firestorm Phoenix back in hand under its own lock: refused by the
	# engine, so never planned by the AI.
	var ai := _wizard(0)
	var phoenix := give_hand(0, "Firestorm Phoenix")   # {4}{R}{R}
	_lands(0, "Mountain", 6)
	advance_to_step(Mtg.Step.MAIN1)
	g._lock_in_hand(phoenix)
	assert_refused(g.cast_spell(0, phoenix), "can't be played")
	assert_eq(ai.act(g), "pass")
	assert_true(_all_untapped(0, "Mountain"))


# ----------------------------------------------- 5. protection (MEDIUM) --

func test_pro_black_knight_blocks_the_black_raider() -> void:
	# Erg Raiders (black 2/3) attacks; our White Knight (pro-black 2/2
	# first strike) takes no damage from it (CR 702.16e) — a free block
	# the maths used to score as a death.
	var ai := _wizard(1)
	var raiders := put_battlefield(0, "Erg Raiders")
	var knight := put_battlefield(1, "White Knight")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [raiders.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	ai.act(g)
	assert_eq(int(g.combat.blocks.get(knight.id, -1)), raiders.id, "the knight blocks for free")


# --------------------------------------- 6. colour-aware reach (MEDIUM) --

func test_pump_reach_counts_only_the_colour_it_needs() -> void:
	# Frozen Shade ({B}: +1/+1) blocked by a Wall of Wood (0/3) with one
	# Swamp and three Forests open: the old reach counted four pumps,
	# bought one it could not follow up, and wasted the Swamp.
	var ai := _wizard(0)
	var shade := put_battlefield(0, "Frozen Shade")
	put_battlefield(0, "Swamp")
	_lands(0, "Forest", 3)
	var wall := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [shade.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: shade.id}))
	assert_eq(g.priority_player, 0)
	assert_eq(ai.act(g), "pass")
	assert_true(_all_untapped(0, "Swamp"), "one pump cannot kill the wall — none bought")


# ------------------------------------ 7. free ability loop (MEDIUM) --

func test_free_untapped_ability_does_not_fire_forever_at_the_sink() -> void:
	# A synthetic "{0}: You gain 1 life" with no tap, no cap: the sink
	# scored it positive every priority pass and it never stopped.
	var ai := _wizard(0)
	var data := CardData.new("Fountain of Youth", "{1}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("", false, [GainLifeEffect.new(1)],
			"{0}: You gain 1 life."))
	put_synthetic(0, data)
	_their_turn_at(Mtg.Step.END)
	assert_eq(ai.act(g), "pass")
	assert_true(g.stack.is_empty())


# ------------------------------------------------------- 8. LOW mirrors --

func test_jandors_ring_waits_for_a_card_drawn_this_turn() -> void:
	# "Discard the last card you drew this turn": nothing drawn, nothing
	# to discard — the engine refuses, so the AI must not tap for it.
	var ai := _wizard(0)
	put_battlefield(0, "Jandor's Ring")
	_lands(0, "Mountain", 2)
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(g.players[0].drawn_this_turn.is_empty(), "the first turn skips the draw")
	assert_eq(ai.act(g), "pass")
	assert_true(_all_untapped(0, "Mountain"))


func test_orcish_artillery_keeps_its_recoil_for_a_creature_at_the_sink() -> void:
	# Three life a shot for two at a face at twenty is still a losing
	# trade at the end of their turn — the sink bonus must not buy it.
	var ai := _wizard(0)
	put_battlefield(0, "Orcish Artillery")
	_their_turn_at(Mtg.Step.END)
	assert_eq(ai.act(g), "pass")
	assert_eq(g.players[0].life, 20)


func test_main_phase_activation_respects_the_held_reserve() -> void:
	# Four Swamps, a Tome and a Terror in hand with a Serra across the
	# table: the Tome draw would tap the mana the Terror is waiting for.
	var ai := _wizard(0)
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Swamp", 4)
	give_hand(0, "Terror")
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	assert_true(_all_untapped(0, "Swamp"), "the Terror's mana stays open")


func test_effect_intent_reads_an_x_pump() -> void:
	var howl := CardRegistry.get_card("Howl from Beyond")
	var intent := EffectIntent.read(howl.spell_effects, howl.card_name)
	assert_true(intent.pumps)
	assert_true(intent.pump_uses_x, "+X/+0 reads as an X pump, not +0/+0")


static func _only_with_an_empty_pool(game: MtgGame, p_pid: int) -> String:
	# A rider the AI's own pre-check cannot foresee: it is true BEFORE the
	# planner taps for the spell and false the moment it has.
	if game.players[p_pid].mana_pool.total() > 0:
		return "cast only while your mana pool is empty"
	return ""


func test_a_refused_cast_is_not_replanned_in_the_same_step() -> void:
	# Belt and braces for every mirror the AI lacks: a cast the engine
	# refused after the taps is remembered for the rest of the step, so a
	# second priority pass in the same step does not tap for it again.
	var ai := _wizard(0)
	var data := CardData.new("Pool Shade", "{B}{B}", Mtg.CardType.CREATURE) \
		.pt(6, 6).castable_only_when(_only_with_an_empty_pool)
	var shade := CardInstance.new(data, g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[shade.id] = shade
	shade.zone = Mtg.Zone.HAND
	g.players[0].hand.append(shade)
	var raiders := give_hand(0, "Erg Raiders")
	_lands(0, "Swamp", 4)
	var ritual := give_hand(1, "Dark Ritual")
	advance_to_step(Mtg.Step.MAIN1)
	# Act 1: the Shade outranks the Raiders, the taps land, the rider bites.
	assert_eq(ai.act(g), "pass")
	assert_eq(shade.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].mana_pool.total(), 2, "the refused cast left its mana floating")
	# Hand priority back to seat 0 in the same step, with an empty pool:
	# seat 1 casts an instant, seat 0 spends the float on the Raiders.
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(1, ritual))
	assert_ok(g.pass_priority(1))
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 0)
	assert_ok(g.cast_spell(0, raiders))
	resolve_stack()
	assert_eq(g.priority_player, 0)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(g.current_step(), Mtg.Step.MAIN1)
	# Act 2, same step: the memo skips the Shade; nothing more is tapped.
	assert_eq(ai.act(g), "pass")
	var untapped := 0
	for inst in g.players[0].battlefield:
		if inst.data.card_name == "Swamp" and not inst.tapped:
			untapped += 1
	assert_eq(untapped, 2, "the two remaining Swamps were not tapped for a known refusal")


# --------------------------------- 9. one shield per creature (MEDIUM) --

func test_a_shield_on_the_stack_is_not_bought_twice() -> void:
	# Our Drudge Skeletons blocks their Bears with two Swamps open. The
	# first shield goes on the stack; they answer with a Giant Growth on
	# the Bears, and we get priority back with our shield still waiting
	# underneath it. The counter only rises when the shield resolves, so
	# the "no shield yet" read bought a second one with the other Swamp —
	# mana burnt for nothing.
	var ai := _wizard(1)
	var bears := put_battlefield(0, "Grizzly Bears")
	var growth := give_hand(0, "Giant Growth")
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	_lands(1, "Swamp", 2)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {skeletons.id: bears.id}))
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	assert_string_contains(ai.act(g), "shields Drudge Skeletons")
	assert_eq(g.stack.size(), 1)
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bears)]))
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	assert_eq(g.stack.size(), 2, "their Growth sits on top of our shield")
	assert_eq(ai.act(g), "pass", "the shield is already on the stack")
	# Our pass was the second in a row: the Growth resolved and only the
	# one shield is left waiting.
	assert_eq(bears.cur_power, 5)
	assert_eq(g.stack.size(), 1, "no second shield")
	var untapped := 0
	for inst in g.players[1].battlefield:
		if inst.data.card_name == "Swamp" and not inst.tapped:
			untapped += 1
	assert_eq(untapped, 1, "the second Swamp stays untapped")


# ------------------------------ 12. counter-hold reads live mana (LOW) --

func test_counter_hold_counts_the_live_blue_sources() -> void:
	# Two of our Mountains are Islands under Phantasmal Terrain (the aura
	# picks the type we have fewest of). Holding a Counterspell, the cast
	# of a marginal 1/1 off the last real Mountain still leaves {U}{U}
	# open — but the old count read the PRINTED abilities, saw no blue at
	# all, and held the Raiders back for a counter it could already keep.
	var ai := _wizard(0)
	_lands(0, "Plains", 2)
	_lands(0, "Swamp", 2)
	_lands(0, "Forest", 2)
	var mountain_a := put_battlefield(0, "Mountain")
	var mountain_b := put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	for host in [mountain_a, mountain_b]:
		var terrain := give_hand(0, "Phantasmal Terrain")
		add_mana(0, Mtg.ManaColor.U, 2)
		assert_ok(g.cast_spell(0, terrain, [TargetRef.card(host)]))
		resolve_stack()
		assert_true(host.has_subtype("island"), "%s became an Island" % host.data.card_name)
	give_hand(0, "Counterspell")
	give_hand(0, "Mons's Goblin Raiders")   # {R} 1/1: marginal
	assert_string_contains(ai.act(g), "cast Mons's Goblin Raiders")
	resolve_stack()
	assert_not_null(g.find_on_battlefield(0, "Mons's Goblin Raiders"))
	assert_false(mountain_a.tapped, "{U}{U} stays open for the Counterspell")
	assert_false(mountain_b.tapped)
