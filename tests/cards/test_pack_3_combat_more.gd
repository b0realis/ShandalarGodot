extends GameTest

func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)

func test_weathervane_changes_only_snow_and_survives_cleanup() -> void:
	var vane := put_battlefield(0, "Arcum's Weathervane")
	var snow := put_battlefield(0, "Snow-Covered Island")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, vane, 0, [TargetRef.card(snow)]))
	resolve_stack()
	assert_eq(snow.cur_supertypes & Mtg.Supertype.SNOW, 0)
	assert_true(snow.has_subtype("island"))
	g.continuous.expire_until_eot()
	g.recalculate()
	assert_eq(snow.cur_supertypes & Mtg.Supertype.SNOW, 0)
	g.untap_permanent(vane)
	assert_ok(g.activate_ability(0, vane, 1, [TargetRef.card(snow)]))
	resolve_stack()
	assert_ne(snow.cur_supertypes & Mtg.Supertype.SNOW, 0)

func test_norritt_can_draft_own_creature_but_not_new_creature() -> void:
	var imp := put_battlefield(0, "Norritt")
	var bear := put_battlefield(0, "Grizzly Bears")
	var new_bear := put_battlefield(0, "Grizzly Bears", true)
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, imp, 1, [TargetRef.card(new_bear)]))
	assert_ok(g.activate_ability(0, imp, 1, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.must_attack_this_turn)

func test_cohort_trigger_survives_source_leaving_but_not_victim_blink() -> void:
	var cohort := put_battlefield(0, "Lim-Dûl's Cohort")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.dispatch_event(Mtg.EventType.BLOCKED, {"attacker": cohort, "blocker": bear})
	g.return_to_hand(cohort)
	resolve_stack()
	assert_true(bear.regeneration_banned_this_turn)

func test_dread_wight_grants_persistent_lock_and_real_paid_unlock() -> void:
	var wight := put_battlefield(0, "Dread Wight")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wight.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: wight.id}))
	g.dispatch_event(Mtg.EventType.END_OF_COMBAT, {"player": 0})
	resolve_stack()
	assert_eq(int(bear.counters.get("paralyzation", 0)), 1)
	assert_true(bear.tapped)
	g.return_to_hand(wight)
	assert_true(bear.cur_skips_untap)
	g.priority_player = 1
	add_mana(1, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(1, bear, 0))
	resolve_stack()
	assert_false(bear.cur_skips_untap)
	assert_true(bear.tapped, "removing the counter doesn't itself untap")

func test_frostbeast_destroys_blockers_once_at_end_of_combat() -> void:
	var beast := put_battlefield(0, "Kjeldoran Frostbeast")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [beast.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: beast.id}))
	g.dispatch_event(Mtg.EventType.END_OF_COMBAT, {"player": 0})
	g.return_to_hand(beast)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)

func test_marton_counts_other_attackers_at_resolution() -> void:
	var marton := put_battlefield(0, "Márton Stromgald")
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [marton.id, a.id, b.id]))
	resolve_stack()
	assert_eq(a.cur_power, 4)
	assert_eq(b.cur_power, 4)
	assert_eq(marton.cur_power, 1)

func test_titan_triggers_on_black_spell_cast_not_resolution() -> void:
	var titan := put_battlefield(0, "Mountain Titan")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.activate_ability(0, titan, 0))
	resolve_stack()
	var ritual := give_hand(0, "Dark Ritual")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, ritual))
	g.counter_spell(ritual)
	resolve_stack()
	assert_eq(titan.cur_power, 3)

func test_total_war_spares_walls_new_creatures_and_tapped_bystanders() -> void:
	put_battlefield(1, "Total War")
	var attacker := put_battlefield(0, "Grizzly Bears")
	var doomed := put_battlefield(0, "Grizzly Bears")
	var tapped := put_battlefield(0, "Grizzly Bears")
	var fresh := put_battlefield(0, "Grizzly Bears", true)
	var wall := put_battlefield(0, "Wall of Wood")
	g.tap_permanent(tapped)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	assert_eq(doomed.zone, Mtg.Zone.GRAVEYARD)
	for i in [tapped, fresh, wall, attacker]: assert_eq(i.zone, Mtg.Zone.BATTLEFIELD)

func test_sappers_self_target_is_not_destroyed_twice_through_regeneration() -> void:
	var sappers := put_battlefield(0, "Goblin Sappers")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, sappers, 0, [TargetRef.card(sappers)]))
	resolve_stack()
	sappers.regeneration_shields = 1
	g.dispatch_event(Mtg.EventType.END_OF_COMBAT, {"player": 0})
	resolve_stack()
	assert_eq(sappers.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(sappers.regeneration_shields, 0)

func test_phantasmal_mount_departure_before_resolution_is_not_retroactive() -> void:
	var mount := put_battlefield(0, "Phantasmal Mount")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, mount, 0, [TargetRef.card(bear)]))
	g.return_to_hand(mount)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.cur_power, 3)

func test_venom_deduplicates_previous_and_current_blocks() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: bear.id}))
	var breath := give_hand(0, "Venomous Breath")
	add_mana(0, Mtg.ManaColor.G, 4)
	assert_ok(g.cast_spell(0, breath, [TargetRef.card(bear)]))
	resolve_stack()
	blocker.regeneration_shields = 1
	g.dispatch_event(Mtg.EventType.END_OF_COMBAT, {"player": 0})
	resolve_stack()
	assert_eq(blocker.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(blocker.regeneration_shields, 0)

## Answers every option question with a fixed index.
class OptionSeat extends DecisionAgent:
	var index := 0
	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			_options: Array[String], _hint: int) -> int:
		return index

func test_barbarian_guides_asks_for_the_land_type_and_returns_the_creature() -> void:
	# "Choose a land type. Target creature you control gains snow landwalk
	# of the chosen type until end of turn." The type list reaches
	# DecisionAgent.choose_option, whose options parameter is
	# Array[String]; an untyped constant made the call fail and the
	# landwalk fall back to the first entry with no question asked.
	var seat := OptionSeat.new()
	seat.index = 4   # forest
	g.set_agent(0, seat)
	var guides := put_battlefield(0, "Barbarian Guides")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.activate_ability(0, guides, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("snow forest"), "the chosen type was applied")
	assert_eq(g.choice_log.size(), 1, "the type question is on the record")
	advance_to_next_turn()
	assert_eq(bear.zone, Mtg.Zone.HAND, "returned at the next end step")

# --- BANDING (bug pass 2026-10-03). "Blocking or blocked by this creature"
# includes the band (CR 702.22h: a creature blocking one band member blocks
# every member). The blocks are declared on the OTHER member, and a blocker's
# combat damage is prevented where it would otherwise kill a band member
# before the end-of-combat trigger looks (setup only).

## P0 attacks with [param band] as one band; P1 then declares [param block_map].
func _band_attack(band: Array, block_map: Dictionary) -> void:
	var ids: Array = []
	for inst in band: ids.append(inst.id)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids, [ids]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, block_map))

func test_frostbeast_in_a_band_destroys_the_creature_blocking_its_band_mate() -> void:
	var beast := put_battlefield(0, "Kjeldoran Frostbeast")
	var bearer := put_battlefield(0, "Shield Bearer")
	var wall := put_battlefield(1, "Wall of Stone")
	_band_attack([beast, bearer], {wall.id: bearer.id})
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)

func test_frostbeast_blocking_a_band_destroys_every_member() -> void:
	var bearer := put_battlefield(0, "Shield Bearer")
	var phalanx := put_battlefield(0, "Kjeldoran Phalanx")
	var beast := put_battlefield(1, "Kjeldoran Frostbeast")
	_band_attack([bearer, phalanx], {beast.id: bearer.id})
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bearer.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(phalanx.zone, Mtg.Zone.GRAVEYARD, "the band-mate was blocked by it too")

func test_dread_wight_blocking_a_band_paralyzes_every_member() -> void:
	var bearer := put_battlefield(0, "Shield Bearer")
	var phalanx := put_battlefield(0, "Kjeldoran Phalanx")
	var wight := put_battlefield(1, "Dread Wight")
	g.continuous.add_until_eot_combat_prevention(wight.id, true, false)
	_band_attack([bearer, phalanx], {wight.id: phalanx.id})
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wight.zone, Mtg.Zone.BATTLEFIELD)
	for member in [bearer, phalanx]:
		assert_eq(member.zone, Mtg.Zone.BATTLEFIELD)
		assert_eq(int(member.counters.get("paralyzation", 0)), 1, member.data.card_name)
