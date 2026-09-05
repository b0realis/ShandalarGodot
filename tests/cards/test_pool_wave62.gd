extends GameTest
## Wave-62 tests: the ABILITY_ACTIVATED event and the three cards that
## needed it — Artifact Possession (new), plus the second printed clause of
## Powerleech and Haunting Wind, which were shipped without it
## (docs/simplified-cards.md, "Powerleech / Haunting Wind" — row removed).


func test_registry_loaded_wave62() -> void:
	for name in ["Artifact Possession", "Powerleech", "Haunting Wind"]:
		assert_not_null(CardRegistry.get_card(name), name)


## Walk the turn machine until [param pid] is the active player and holds
## priority in their first main phase — where sorcery-speed things happen.
func reach_main_phase_of(pid: int) -> void:
	var guard := 0
	while (g.active_player != pid or g.current_step() != Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached P%d's main phase" % pid)


## Cast an Aura the honest way, from [param pid]'s own main phase.
func cast_aura(pid: int, aura_name: String, host: CardInstance) -> CardInstance:
	var aura := give_hand(pid, aura_name)
	reach_main_phase_of(pid)
	add_mana(pid, Mtg.ManaColor.B, aura.data.cost.mana_value())
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(aura.attached_to, host.id, "%s attached" % aura_name)
	return aura


# ------------------------------------------------------- the engine event --

func test_ability_activated_names_the_permanent_the_activator_and_the_tap() -> void:
	var monolith := put_battlefield(1, "Basalt Monolith")
	reach_main_phase_of(1)
	var seen: Array = []
	g.event_occurred.connect(func(ev: GameEvent) -> void:
		if ev.type == Mtg.EventType.ABILITY_ACTIVATED:
			seen.append(ev.data))
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, monolith, 0))
	assert_eq(seen.size(), 1, "one activation, one event")
	assert_eq(seen[0]["instance"], monolith)
	assert_eq(seen[0]["controller"], 1, "the permanent's controller")
	assert_eq(seen[0]["player"], 1, "who activated it")
	assert_false(bool(seen[0]["taps"]), "{3}: Untap has no {T} in its cost")


func test_ability_activated_marks_a_tap_cost() -> void:
	var icy := put_battlefield(0, "Icy Manipulator")
	var bear := put_battlefield(1, "Grizzly Bears")
	var taps: Array = []
	g.event_occurred.connect(func(ev: GameEvent) -> void:
		if ev.type == Mtg.EventType.ABILITY_ACTIVATED:
			taps.append(bool(ev.data["taps"])))
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, icy, 0, [TargetRef.card(bear)]))
	assert_eq(taps, [true], "{1}, {T} is a tap cost")


func test_ability_activated_fires_before_the_ability_resolves() -> void:
	# CR 602.2b/603.3b: the ability is on the stack first, so anything that
	# triggers on its ACTIVATION goes on top and resolves first.
	var monolith := put_battlefield(1, "Basalt Monolith")
	cast_aura(0, "Artifact Possession", monolith)
	reach_main_phase_of(1)
	monolith.tapped = true          # it skips its own untap step anyway
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, monolith, 0))
	assert_eq(g.stack.size(), 2)
	assert_eq(g.stack[1].kind, Mtg.StackKind.TRIGGER, "the sting is on top")
	assert_true(monolith.tapped, "and the untap has not happened yet")


func test_a_mana_ability_without_a_tap_is_an_activation_too() -> void:
	# CR 605.1a. Ashnod's Altar's whole cost is "Sacrifice a creature".
	var altar := put_battlefield(1, "Ashnod's Altar")
	put_battlefield(1, "Grizzly Bears")
	cast_aura(0, "Artifact Possession", altar)
	assert_ok(g.tap_for_mana(1, altar, 0))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "the Altar's meal cost 2 life")


# -------------------------------------------------- Artifact Possession --

func test_artifact_possession_stings_a_tapless_activation() -> void:
	var monolith := put_battlefield(1, "Basalt Monolith")
	cast_aura(0, "Artifact Possession", monolith)
	reach_main_phase_of(1)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, monolith, 0))
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].life, 20, "the Aura's controller is untouched")


func test_artifact_possession_stings_a_tap_ability_exactly_once() -> void:
	# Duel.hlp's own ruling: "Tapping an artifact as part of its activation
	# cost will only cause Artifact Possession's ability to trigger once."
	var icy := put_battlefield(1, "Icy Manipulator")
	var bear := put_battlefield(0, "Grizzly Bears")
	cast_aura(0, "Artifact Possession", icy)
	reach_main_phase_of(1)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, icy, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "one trigger, not two")


func test_artifact_possession_stings_a_plain_tap() -> void:
	var monolith := put_battlefield(1, "Basalt Monolith")
	cast_aura(0, "Artifact Possession", monolith)
	assert_ok(g.tap_for_mana(1, monolith, 0))
	resolve_stack()
	assert_eq(g.players[1].life, 18)


func test_artifact_possession_ignores_an_artifact_it_is_not_on() -> void:
	var mine := put_battlefield(1, "Basalt Monolith")
	var other := put_battlefield(1, "Basalt Monolith")
	cast_aura(0, "Artifact Possession", mine)
	reach_main_phase_of(1)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, other, 0))
	resolve_stack()
	assert_eq(g.players[1].life, 20)


# --------------------------------------------------------- Powerleech --

func test_powerleech_drinks_an_opponents_tapless_activation() -> void:
	put_battlefield(0, "Powerleech")
	var monolith := put_battlefield(1, "Basalt Monolith")
	reach_main_phase_of(1)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, monolith, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 21)


func test_powerleech_ignores_our_own_activation() -> void:
	put_battlefield(0, "Powerleech")
	var monolith := put_battlefield(0, "Basalt Monolith")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, monolith, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 20)


func test_powerleech_drinks_an_opponents_tap_ability_only_once() -> void:
	put_battlefield(0, "Powerleech")
	var icy := put_battlefield(1, "Icy Manipulator")
	var bear := put_battlefield(0, "Grizzly Bears")
	reach_main_phase_of(1)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, icy, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(g.players[0].life, 21, "the tap clause alone")


# ------------------------------------------------------- Haunting Wind --

func test_haunting_wind_stings_its_own_controller_too() -> void:
	put_battlefield(0, "Haunting Wind")
	var ours := put_battlefield(0, "Basalt Monolith")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, ours, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 19, "the Wind is symmetric")
	assert_eq(g.players[1].life, 20)


func test_haunting_wind_stings_the_other_side_as_well() -> void:
	put_battlefield(0, "Haunting Wind")
	var theirs := put_battlefield(1, "Basalt Monolith")
	reach_main_phase_of(1)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, theirs, 0))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(g.players[0].life, 20)


func test_haunting_wind_stings_a_tap_ability_only_once() -> void:
	put_battlefield(0, "Haunting Wind")
	var icy := put_battlefield(1, "Icy Manipulator")
	var bear := put_battlefield(0, "Grizzly Bears")
	reach_main_phase_of(1)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, icy, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
