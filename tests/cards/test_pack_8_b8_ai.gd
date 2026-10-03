extends GameTest
## Pack 8 (the Mirage block), batch B8 — the fair AI and this batch's costs:
## it prices and pays them (E6's object-cost pricing), keeps its lands when
## an alternative cost is not worth them, and pays (or lets go) the
## cumulative upkeeps. Simple probes where the right play is plain.
## The mode pickers themselves are pinned beside their cards
## (test_pack_8_b8_visions.gd, test_pack_8_b8_weatherlight.gd); casting
## through an alternative row, object-cost-only abilities (Necratog, Zombie
## Scavengers) and targeted life loss (Kaervek's Spite for the win) are the
## AI agent's to pin at action level (engine/ai).

const OC := preload("res://engine/additional_object_costs.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _pilot(pid: int) -> AiPlayer:
	var ai := AiPlayer.new(pid, AiProfile.wizard())
	ai.profile.develops_late = false
	ai.profile.holds_x_burn = 0
	g.set_agent(pid, ai)
	return ai

func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst

func _count(pid: int, card_name: String) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if i.data.card_name == card_name: n += 1
	return n


# --- alternative costs --------------------------------------------------------

func test_ai_pays_fireblasts_mana_when_it_can_and_keeps_its_lands() -> void:
	var ai := _pilot(0)
	for i in 6: put_battlefield(0, "Mountain")
	var blast := give_hand(0, "Fireblast")
	g.players[1].life = 4
	ai.act(g)
	assert_eq(blast.zone, Mtg.Zone.STACK)
	assert_eq(_count(0, "Mountain"), 6, "the printed {4}{R}{R} was paid instead")

func test_ai_does_not_throw_mountains_at_nothing() -> void:
	var ai := _pilot(0)
	for i in 2: put_battlefield(0, "Mountain")
	var blast := give_hand(0, "Fireblast")
	ai.act(g)
	assert_eq(blast.zone, Mtg.Zone.HAND)
	assert_eq(_count(0, "Mountain"), 2)

# --- additional costs ---------------------------------------------------------

func test_ai_keeps_kaervek_s_spite_when_it_does_not_win() -> void:
	var ai := _pilot(0)
	for i in 3: put_battlefield(0, "Swamp")
	put_battlefield(0, "Grizzly Bears")
	var spite := give_hand(0, "Kaervek's Spite")
	ai.act(g)
	assert_eq(spite.zone, Mtg.Zone.HAND, "the whole board for 5 life is not worth it")
	assert_eq(_count(0, "Swamp"), 3)

func test_ai_sizes_haunting_misery_from_its_graveyard_for_the_win() -> void:
	var ai := _pilot(0)
	for i in 3: put_battlefield(0, "Swamp")
	_in_graveyard(0, "Grizzly Bears")
	_in_graveyard(0, "Hill Giant")
	give_hand(0, "Haunting Misery")
	g.players[1].life = 2
	ai.act(g)
	resolve_stack()
	assert_true(g.game_over)


# --- activated costs --------------------------------------------------------------

func test_ai_sheeps_a_threat_with_ovinomancer() -> void:
	var ai := _pilot(0)
	for i in 6: put_battlefield(0, "Island")
	var wizard := put_battlefield(0, "Ovinomancer")
	resolve_stack()   # its arrival: three of the six Islands go back
	assert_eq(wizard.zone, Mtg.Zone.BATTLEFIELD, "the AI keeps it when the lands can be spared")
	var wurm := put_battlefield(1, "Craw Wurm")
	var guard := 0
	while wurm.zone == Mtg.Zone.BATTLEFIELD and guard < 6 and g.active_player == 0 \
			and Mtg.is_main_step(g.current_step()):
		ai.act(g)
		resolve_stack()
		guard += 1
	assert_eq(wizard.zone, Mtg.Zone.HAND, "returned as the cost")
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_count(1, "Sheep"), 1)


# --- cumulative upkeep ---------------------------------------------------------------

func test_ai_pays_an_affordable_upkeep_and_lets_a_dear_one_go() -> void:
	var ai := _pilot(0)
	var efreet := put_battlefield(0, "Uktabi Efreet")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	ai.prepare(g, 0)
	g.set_agent(1, DecisionAgent.new())
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(efreet.zone, Mtg.Zone.BATTLEFIELD, "{G} for a 5/4: paid")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(efreet.zone, Mtg.Zone.BATTLEFIELD, "{G}{G}: still paid")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(efreet.zone, Mtg.Zone.GRAVEYARD, "{G}{G}{G} with two Forests cannot be paid")
