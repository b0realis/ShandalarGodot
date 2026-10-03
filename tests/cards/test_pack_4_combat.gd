extends GameTest
## Pair colours and identities are captured at the event, not reconstructed
## from a later board. End-of-combat costs refer to this combat only.

func before_each() -> void:
	CardPacks.set_enabled("pack-4", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-4", false)

func blocks(attacker: CardInstance, blocker: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: attacker.id}))
	resolve_stack()

func test_root_spider_and_folk_blocking_triggers() -> void:
	var a := put_battlefield(0, "Grizzly Bears")
	var spider := put_battlefield(1, "Root Spider")
	blocks(a, spider)
	assert_eq(spider.cur_power, 3)
	assert_true(spider.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(spider.zone, Mtg.Zone.BATTLEFIELD)

func test_ghost_hounds_get_first_strike_against_white_only() -> void:
	var hounds := put_battlefield(0, "Ghost Hounds")
	var white := put_battlefield(1, "Savannah Lions")
	blocks(hounds, white)
	assert_true(hounds.has_keyword(Mtg.Keyword.VIGILANCE))
	assert_true(hounds.has_keyword(Mtg.Keyword.FIRST_STRIKE))

func test_inquisitors_bonus_is_once_for_multiple_black_blockers() -> void:
	var inquisitors := put_battlefield(0, "Serra Inquisitors")
	var a := put_battlefield(1, "Sengir Bats")
	var b := put_battlefield(1, "Sengir Bats")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [inquisitors.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: inquisitors.id, b.id: inquisitors.id}))
	resolve_stack()
	assert_eq(inquisitors.cur_power, 5)

func test_labyrinth_minotaur_skips_the_blocked_creatures_next_untap() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var minotaur := put_battlefield(1, "Labyrinth Minotaur")
	blocks(bear, minotaur)
	assert_true(bear.skip_next_untap)

func test_sea_troll_can_regenerate_only_after_fighting_blue_this_turn() -> void:
	var troll := put_battlefield(1, "Sea Troll")
	var blue := put_battlefield(0, "Labyrinth Minotaur")
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, troll, 0))
	blocks(blue, troll)
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, troll, 0))
	resolve_stack()
	g.destroy(troll)
	assert_eq(troll.zone, Mtg.Zone.BATTLEFIELD)

func test_clockwork_winds_down_even_if_removed_from_combat_without_leaving() -> void:
	var steed := put_battlefield(0, "Clockwork Steed")
	assert_eq(steed.cur_power, 4)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [steed.id]))
	g.remove_from_combat(steed)
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(int(steed.counters.get("+1/+0", 0)), 3)
	advance_to_step(Mtg.Step.MAIN2)
	g.dispatch_event(Mtg.EventType.END_OF_COMBAT, {"player": 0})
	resolve_stack()
	assert_eq(int(steed.counters.get("+1/+0", 0)), 3, "previous combat must not charge twice")

func test_clockwork_evasion_and_upkeep_rewinding_cap_four() -> void:
	var steed := put_battlefield(0, "Clockwork Steed")
	var swarm := put_battlefield(0, "Clockwork Swarm")
	var artifact := put_battlefield(1, "Clockwork Gnomes")
	var wall := put_battlefield(1, "Wall of Wood")
	assert_ne(CombatState.block_illegality(g, artifact, steed, 1), "")
	assert_ne(CombatState.block_illegality(g, wall, swarm, 1), "")
	g.remove_counters(steed, "+1/+0", 3)
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.C, 10)
	assert_ok(g.activate_ability(0, steed, 0, [], 7))
	resolve_stack()
	assert_eq(int(steed.counters.get("+1/+0", 0)), 4)

func test_greater_werewolf_places_a_counter_not_damage_at_combat_end() -> void:
	var wolf := put_battlefield(0, "Greater Werewolf")
	var wall := put_battlefield(1, "Wall of Stone")
	blocks(wolf, wall)
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(int(wall.counters.get("-0/-2", 0)), 1)
	assert_eq(wall.cur_toughness, 6)

func test_ferrets_delayed_tap_uses_this_turns_blockers_and_skips_next_untap() -> void:
	var ferrets := put_battlefield(0, "Joven's Ferrets")
	var bear := put_battlefield(1, "Grizzly Bears")
	blocks(ferrets, bear)
	assert_eq(ferrets.cur_toughness, 3)
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_true(bear.tapped)
	assert_true(bear.skip_next_untap)

func test_spectral_bears_ignore_black_tokens_but_accept_black_nontoken_lands() -> void:
	var bears := put_battlefield(0, "Spectral Bears")
	g.create_token(1, CardData.new("Black token", "", Mtg.CardType.CREATURE).pt(0, 1).with_colors(Mtg.ManaColor.B))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	resolve_stack()
	assert_eq(bears.skip_untap_for, [0])

func test_heart_wolf_sacrifice_trigger_survives_ability_source_removal_and_blink() -> void:
	var wolf := put_battlefield(0, "Heart Wolf")
	var dwarf := put_battlefield(0, "Dwarven Trader")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_ok(g.activate_ability(0, wolf, 0, [TargetRef.card(dwarf)]))
	resolve_stack()
	assert_eq(dwarf.cur_power, 3)
	g.return_to_hand(dwarf)
	resolve_stack()
	assert_eq(wolf.zone, Mtg.Zone.GRAVEYARD)

func test_baron_does_not_get_credit_for_damage_from_its_previous_incarnation() -> void:
	var baron := put_battlefield(0, "Baron Sengir")
	var wall := put_battlefield(1, "Wall of Stone")
	g.deal_damage(baron, TargetRef.card(wall), 1)
	g.return_to_hand(baron)
	g.put_from_hand_into_play(baron, 0)
	g.destroy(wall)
	resolve_stack()
	assert_eq(int(baron.counters.get("+2/+2", 0)), 0)

# --- BANDING (bug pass 2026-10-03). A creature blocking one member of a band
# blocks every member (CR 702.22h); the blocks below are declared on the OTHER
# member. Benalish Hero and Timber Wolves are the base game's 1/1 banders.

## P0 attacks with [param band] as one band; P1 then declares [param block_map].
func _band_attack(band: Array, block_map: Dictionary) -> void:
	var ids: Array = []
	for inst in band: ids.append(inst.id)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids, [ids]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, block_map))
	resolve_stack()

func test_greater_werewolf_blocking_a_band_counters_every_member() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var wolves := put_battlefield(0, "Timber Wolves")
	var wolf := put_battlefield(1, "Greater Werewolf")
	# Setup: its own combat damage would kill a 1/1 first.
	g.continuous.add_until_eot_combat_prevention(wolf.id, true, false)
	_band_attack([hero, wolves], {wolf.id: hero.id})
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(hero.zone, Mtg.Zone.GRAVEYARD, "-0/-2 on a 1/1")
	assert_eq(wolves.zone, Mtg.Zone.GRAVEYARD, "the band-mate was blocked by it too")

func test_inquisitors_get_the_bonus_from_a_black_creature_blocking_their_band() -> void:
	var inquisitors := put_battlefield(0, "Serra Inquisitors")
	var hero := put_battlefield(0, "Benalish Hero")
	var zombies := put_battlefield(1, "Scathe Zombies")
	_band_attack([inquisitors, hero], {zombies.id: hero.id})
	assert_eq(inquisitors.cur_power, 5)

func test_rashka_blocking_a_band_with_a_black_member_gets_the_bonus() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var zombies := put_battlefield(0, "Scathe Zombies")
	var rashka := put_battlefield(1, "Rashka the Slayer")
	_band_attack([hero, zombies], {rashka.id: hero.id})
	assert_eq(Vector2i(rashka.cur_power, rashka.cur_toughness), Vector2i(4, 5))
