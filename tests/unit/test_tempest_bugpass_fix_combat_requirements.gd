extends GameTest
## BLOCK REQUIREMENTS COUNTED, NOT CHECKED ONE BY ONE (Pack 9 bug pass,
## CR 509.1c): "the number of requirements being obeyed must be maximized
## without violating any restrictions". The declaration is judged against
## the best any legal, cost-free declaration could do
## ([method CombatDeclaration.must_block_error]); the AI's repair writes such
## a declaration in ([method CombatDeclaration.repair_blocks]).
##
## * Two requirements needing the SAME menace partner (Goblin War Drums):
##   each per-creature check found "a block it could make", so every
##   maximal declaration was refused — a human seat could never leave the
##   step and the AI conceded.
## * A NARROWED Lure (Trumpeting Armodon's chosen creature, Magnetic Web's
##   magnet creatures) bound only the creatures its filter names; it counted
##   as a lure for every blocker, so a creature under a real Lure escaped it.
## * A plain Lure made AFTER a narrowed one was narrowed with it: "all
##   creatures able to block it" is its own flag
##   ([member CardInstance.cur_must_be_blocked_by_all]).
## * Under a blocker cap (Caverns of Despair) a full cap excused every unmet
##   requirement, whatever the creatures in it obeyed.

const CombatDeclaration := preload("res://engine/core/combat_declaration.gd")
const G := Mtg.ManaColor.G


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-2", true)
	CardPacks.set_enabled("pack-6", true)
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-2", false)
	CardPacks.set_enabled("pack-6", false)
	CardPacks.set_enabled("pack-9", false)


func _attack(ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)


func _lure_on(attacker: CardInstance) -> void:
	var lure := give_hand(0, "Lure")
	add_mana(0, G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, lure, [TargetRef.card(attacker)]))
	resolve_stack()
	assert_true(attacker.cur_must_be_blocked)


# =============================================== a shared menace partner ==

## Invasion Plans: every creature blocks if able; the attacking player
## declares. Goblin War Drums gives both attackers menace. The Dryad is the
## only creature that can partner either: the shade pair and the giant pair
## each obey two requirements, the most any declaration can.
func _plans_board() -> Dictionary:
	put_battlefield(0, "Goblin War Drums")
	var shade := put_battlefield(0, "Dauthi Marauder")
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Invasion Plans")
	var dryad := put_battlefield(1, "Heartwood Dryad")
	var soldier := put_battlefield(1, "Soltari Foot Soldier")
	var bears := put_battlefield(1, "Grizzly Bears")
	_attack([shade.id, giant.id])
	assert_eq(g.block_chooser(), 0)
	assert_eq(shade.cur_min_blockers, 2)
	assert_eq(giant.cur_min_blockers, 2)
	return {"shade": shade, "giant": giant, "dryad": dryad, "soldier": soldier, "bears": bears}


func test_shared_partner_invasion_plans_the_shade_pair_is_legal() -> void:
	var b := _plans_board()
	assert_ok(g.declare_blockers(0, {b.dryad.id: b.shade.id, b.soldier.id: b.shade.id}))


func test_shared_partner_invasion_plans_the_giant_pair_is_legal() -> void:
	var b := _plans_board()
	assert_ok(g.declare_blockers(0, {b.dryad.id: b.giant.id, b.bears.id: b.giant.id}))


func test_shared_partner_invasion_plans_still_refuses_fewer() -> void:
	var b := _plans_board()
	assert_refused(g.declare_blockers(0, {}), "blocks each combat if able")
	assert_true(g.awaiting_blockers, "the refusal changed nothing")


func test_shared_partner_invasion_plans_the_ai_chooser_declares() -> void:
	var b := _plans_board()
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	ai.act(g)
	assert_false(g.game_over, "no concession")
	assert_false(g.awaiting_blockers, "a legal declaration was made")
	assert_eq(g.combat.blocks.size(), 2, "two requirements obeyed")


## Watchdog (ground) + a Provoked shade, the Dryad free to partner either:
## one requirement is the most any declaration obeys.
func _watchdog_board() -> Dictionary:
	put_battlefield(0, "Goblin War Drums")
	var shade := put_battlefield(0, "Dauthi Marauder")
	var giant := put_battlefield(0, "Hill Giant")
	var dog := put_battlefield(1, "Watchdog")
	var dryad := put_battlefield(1, "Heartwood Dryad")
	var soldier := put_battlefield(1, "Soltari Foot Soldier")
	advance_to_step(Mtg.Step.MAIN1)
	var provoke := give_hand(0, "Provoke")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, provoke, [TargetRef.card(soldier)]))
	resolve_stack()
	assert_true(soldier.must_block_this_turn_any)
	return {"shade": shade, "giant": giant, "dog": dog, "dryad": dryad, "soldier": soldier}


func test_shared_partner_watchdog_and_provoke_the_shade_pair_is_legal() -> void:
	var b := _watchdog_board()
	_attack([b.shade.id, b.giant.id])
	assert_ok(g.declare_blockers(1, {b.dryad.id: b.shade.id, b.soldier.id: b.shade.id}))


func test_shared_partner_watchdog_and_provoke_the_giant_pair_is_legal() -> void:
	var b := _watchdog_board()
	_attack([b.shade.id, b.giant.id])
	assert_ok(g.declare_blockers(1, {b.dryad.id: b.giant.id, b.dog.id: b.giant.id}))


func test_shared_partner_watchdog_and_provoke_nobody_is_refused() -> void:
	var b := _watchdog_board()
	_attack([b.shade.id, b.giant.id])
	assert_refused(g.declare_blockers(1, {}))
	# The Dryad blocking the giant alone breaks menace (a restriction).
	assert_refused(g.declare_blockers(1, {b.dryad.id: b.giant.id}), "at least 2")


func test_shared_partner_the_ai_defender_declares_instead_of_conceding() -> void:
	var b := _watchdog_board()
	var ai := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, ai)
	_attack([b.shade.id, b.giant.id])
	assert_true(g.awaiting_blockers)
	ai.act(g)
	assert_false(g.game_over, "the defending AI conceded (winner %d)" % g.winner)
	assert_false(g.awaiting_blockers)
	assert_true(g.combat.blocks.has(b.dryad.id), "the Dryad partners one of the two")


## The duel screen's orange "must block" cue asks
## [method CombatDeclaration.forced_block_targets] with the blocks pencilled
## so far: a partner already pencilled against another attacker is spent.
func test_shared_partner_a_spent_partner_is_no_partner_for_the_must_block_cue() -> void:
	var b := _watchdog_board()
	_attack([b.shade.id, b.giant.id])
	assert_eq(CombatDeclaration.forced_block_targets(g, 1, b.dog, {}), [b.giant] as Array[CardInstance],
		"with the Dryad free the Watchdog owes the giant a block")
	var pencilled := {b.dryad.id: [b.shade.id], b.soldier.id: [b.shade.id]}
	assert_true(CombatDeclaration.forced_block_targets(g, 1, b.dog, pencilled).is_empty(),
		"the Dryad is spent on the shade: the Watchdog owes nothing more")


func test_shared_partner_repair_writes_a_declaration_the_engine_accepts() -> void:
	var b := _watchdog_board()
	_attack([b.shade.id, b.giant.id])
	var repaired: Dictionary = CombatDeclaration.repair_blocks(g, 1, {})
	assert_eq(repaired.size(), 2, "one requirement and its partner")
	assert_ok(g.declare_blockers(1, repaired))


## A larger board stays quick and answerable: five creatures under Invasion
## Plans against three menace attackers.
func test_shared_partner_a_crowded_board_is_answered() -> void:
	put_battlefield(0, "Goblin War Drums")
	var ids: Array = []
	for name in ["Dauthi Marauder", "Hill Giant", "Grizzly Bears"]:
		ids.append(put_battlefield(0, name).id)
	put_battlefield(1, "Invasion Plans")
	for name in ["Heartwood Dryad", "Soltari Foot Soldier", "Grizzly Bears",
			"Savannah Lions", "Llanowar Elves"]:
		put_battlefield(1, name)
	_attack(ids)
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var started := Time.get_ticks_msec()
	ai.act(g)
	assert_false(g.game_over, "no concession")
	assert_false(g.awaiting_blockers)
	assert_lt(Time.get_ticks_msec() - started, 20000, "bounded (SEARCH_BUDGET), not exhaustive")


# ================================================= a narrowed lure's reach ==

func test_lure_filter_the_armodon_bystander_obeys_the_real_lure() -> void:
	var armodon := put_battlefield(0, "Trumpeting Armodon")
	var lured := put_battlefield(0, "Grizzly Bears")
	var chosen := put_battlefield(1, "Grizzly Bears")
	var bystander := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.MAIN1)
	_lure_on(lured)
	add_mana(0, G, 2)
	assert_ok(g.activate_ability(0, armodon, 0, [TargetRef.card(chosen)]))
	resolve_stack()
	_attack([armodon.id, lured.id])
	assert_refused(g.declare_blockers(1, {chosen.id: armodon.id, bystander.id: armodon.id}),
		"Savannah Lions must block Grizzly Bears")
	assert_ok(g.declare_blockers(1, {chosen.id: armodon.id, bystander.id: lured.id}))


func test_lure_filter_a_non_magnet_creature_obeys_the_real_lure() -> void:
	put_battlefield(1, "Magnetic Web")
	var magnet := put_battlefield(0, "Hill Giant")
	var lured := put_battlefield(0, "Grizzly Bears")
	var bystander := put_battlefield(1, "Savannah Lions")
	g.add_counters(magnet, "magnet")
	advance_to_step(Mtg.Step.MAIN1)
	_lure_on(lured)
	_attack([magnet.id, lured.id])
	assert_true(magnet.cur_must_be_blocked, "the Web's block half narrowed a Lure onto the magnet attacker")
	assert_false(CombatDeclaration.lure_binds(magnet, bystander), "no magnet counter, no requirement")
	assert_refused(g.declare_blockers(1, {bystander.id: magnet.id}), "must block Grizzly Bears")
	assert_ok(g.declare_blockers(1, {bystander.id: lured.id}))


func test_lure_filter_the_ai_sends_the_bystander_to_the_real_lure() -> void:
	var armodon := put_battlefield(0, "Trumpeting Armodon")
	var lured := put_battlefield(0, "Grizzly Bears")
	var chosen := put_battlefield(1, "Grizzly Bears")
	var bystander := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.MAIN1)
	_lure_on(lured)
	add_mana(0, G, 2)
	assert_ok(g.activate_ability(0, armodon, 0, [TargetRef.card(chosen)]))
	resolve_stack()
	var ai := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, ai)
	_attack([armodon.id, lured.id])
	ai.act(g)
	assert_false(g.game_over, "no concession")
	assert_true(g.combat.is_blocking(bystander.id, lured.id), "the Lions obey the Lure")
	assert_true(g.combat.blocks.has(chosen.id), "the chosen Bears obey a requirement too")


# ============================================ a plain lure after a narrow ==

func test_lure_order_alluring_scent_after_the_armodon_asks_everyone() -> void:
	var armodon := put_battlefield(0, "Trumpeting Armodon")
	var chosen := put_battlefield(1, "Grizzly Bears")
	var other := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, G, 2)
	assert_ok(g.activate_ability(0, armodon, 0, [TargetRef.card(chosen)]))
	resolve_stack()
	var scent := give_hand(0, "Alluring Scent")
	add_mana(0, G, 3)
	assert_ok(g.cast_spell(0, scent, [TargetRef.card(armodon)]))
	resolve_stack()
	assert_true(armodon.cur_must_be_blocked_by_all)
	_attack([armodon.id])
	assert_refused(g.declare_blockers(1, {chosen.id: armodon.id}), "Savannah Lions must block")
	assert_ok(g.declare_blockers(1, {chosen.id: armodon.id, other.id: armodon.id}))


func test_lure_order_alluring_scent_before_the_armodon_asks_everyone() -> void:
	var armodon := put_battlefield(0, "Trumpeting Armodon")
	var chosen := put_battlefield(1, "Grizzly Bears")
	var other := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.MAIN1)
	var scent := give_hand(0, "Alluring Scent")
	add_mana(0, G, 3)
	assert_ok(g.cast_spell(0, scent, [TargetRef.card(armodon)]))
	resolve_stack()
	add_mana(0, G, 2)
	assert_ok(g.activate_ability(0, armodon, 0, [TargetRef.card(chosen)]))
	resolve_stack()
	_attack([armodon.id])
	assert_refused(g.declare_blockers(1, {chosen.id: armodon.id}), "Savannah Lions must block")
	assert_ok(g.declare_blockers(1, {chosen.id: armodon.id, other.id: armodon.id}))


## Marble Priest's own narrowed Lure (Walls) beside a real Lure: every
## creature, whichever static ran last.
func test_lure_order_a_lure_on_marble_priest_asks_every_creature() -> void:
	var priest := put_battlefield(0, "Marble Priest")
	var wall := put_battlefield(1, "Wall of Wood")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_lure_on(priest)
	_attack([priest.id])
	assert_refused(g.declare_blockers(1, {wall.id: priest.id}), "Grizzly Bears must block")
	assert_ok(g.declare_blockers(1, {wall.id: priest.id, bear.id: priest.id}))


func test_lure_order_the_flag_is_rebuilt_each_pass() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var scent := give_hand(0, "Alluring Scent")
	add_mana(0, G, 3)
	assert_ok(g.cast_spell(0, scent, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_must_be_blocked_by_all)
	advance_to_next_turn()
	assert_false(bear.cur_must_be_blocked_by_all, "this turn only")
	assert_false(bear.cur_must_be_blocked)


# ================================================ the cap counts requirements ==

## Caverns of Despair: no more than two creatures can block. Two Watchdogs
## on the lured Bears obey four requirements (two "blocks each combat", two
## Lure) — the most any declaration can.
func _cap_board() -> Dictionary:
	put_battlefield(1, "Caverns of Despair")
	var lured := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var w1 := put_battlefield(1, "Watchdog")
	var w2 := put_battlefield(1, "Watchdog")
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_lure_on(lured)
	_attack([lured.id, giant.id])
	assert_eq(g.max_blockers, 2)
	return {"lured": lured, "giant": giant, "w1": w1, "w2": w2, "bears": bears}


func test_cap_the_bears_and_one_watchdog_obey_fewer() -> void:
	var b := _cap_board()
	assert_refused(g.declare_blockers(1, {b.bears.id: b.lured.id, b.w1.id: b.lured.id}),
		"Watchdog")


func test_cap_two_watchdogs_on_the_giant_dodge_the_lure() -> void:
	var b := _cap_board()
	assert_refused(g.declare_blockers(1, {b.w1.id: b.giant.id, b.w2.id: b.giant.id}),
		"must block Grizzly Bears")


func test_cap_two_watchdogs_on_the_lure_are_the_answer() -> void:
	var b := _cap_board()
	assert_ok(g.declare_blockers(1, {b.w1.id: b.lured.id, b.w2.id: b.lured.id}))


func test_cap_the_ai_repair_finds_the_answer() -> void:
	var b := _cap_board()
	var repaired: Dictionary = CombatDeclaration.repair_blocks(g, 1, {b.bears.id: b.giant.id})
	assert_eq(repaired.size(), 2)
	assert_true(repaired.has(b.w1.id) and repaired.has(b.w2.id))
	assert_ok(g.declare_blockers(1, repaired))
