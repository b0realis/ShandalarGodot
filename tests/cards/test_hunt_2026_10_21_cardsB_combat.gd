extends GameTest
## "BLOCKING IT" AND "BLOCKED BY IT", ASKED OF THE COMBAT AS IT STANDS
## (bug hunt 2026-10-21, cardsB).
##
## Two ways a card read the wrong creatures out of the combat records:
##
## - BANDS. A creature declared as a blocker against one member of a band
##   blocks every member (CR 702.22h); `CombatState.blockers_of` names only
##   the blockers declared straight at one attacker. Coils of the Medusa
##   on the other band member destroyed nothing, Elvish Berserker banded
##   with the creature the blocker was declared on counted no blockers, and
##   Wall of Nets exiled only the band member its block was declared on.
##   They now read `blockers_of_band` / `opposing_attackers`, as Knight of
##   Valor, Spined Sliver and rampage already did.
## - REMOVED FROM COMBAT. An attacker that leaves combat — regenerated
##   (CR 701.15b), or Reconnaissance — is no longer blocked by anything
##   (CR 506.4), but the blocker's entry in `CombatState.blocks` still names
##   it on purpose (engine/combat.gd, `forget`). Kjeldoran Frostbeast
##   destroyed, Dread Wight paralysed and Greater Werewolf shrank the Drudge
##   Skeletons that had just regenerated out of their block, and Wall of
##   Nets exiled the attacker Reconnaissance had pulled out. Goblin Snowman,
##   Tinder Wall and Wall of Corpses could still aim at it as "the creature
##   it's blocking" (Whip Vine and Sworn Defender the same). Their "blocked
##   by this creature" now keeps only the creatures still attacking.
##
## And Blood Frenzy's "cast this spell only before the combat damage step"
## (Berserk's check, handed over by cardsA): it asked only whether the
## REGULAR combat damage step was still ahead, so it stayed castable in the
## first-strike combat damage step — which is a combat damage step too
## (CR 510.4), after the first strikers had already dealt their damage.


func before_each() -> void:
	for id in [IceAgePack.ID, HomelandsPack.ID, MirageBlockPack.ID, TempestBlockPack.ID]:
		CardPacks.set_enabled(id, true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in [IceAgePack.ID, HomelandsPack.ID, MirageBlockPack.ID, TempestBlockPack.ID]:
		CardPacks.set_enabled(id, false)


## Player 0 attacks with [param ids] as one band; player 1 declares
## [param blocks] (blocker id -> attacker id).
func _band_attack(ids: Array, blocks: Dictionary) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids, [ids]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))
	resolve_stack()


## Drudge Skeletons attacks into [param blocker_name], regenerates and
## dies to its damage — so it leaves combat — and combat ends.
func _skeletons_regenerate_out_of(blocker_name: String) -> CardInstance:
	var skeletons := put_battlefield(0, "Drudge Skeletons")
	var blocker := put_battlefield(1, blocker_name)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [skeletons.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: skeletons.id}))
	g.priority_player = 0
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, skeletons, 0))
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	resolve_stack()
	assert_true(skeletons.tapped, "it regenerated (and so left combat)")
	return skeletons


# --------------------------------------------------------------- bands --

func test_coils_of_the_medusa_destroys_the_blocker_of_its_hosts_band() -> void:
	var infantry := put_battlefield(0, "Benalish Infantry")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var coils := give_hand(0, "Coils of the Medusa")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, coils, [TargetRef.card(bear)]))
	resolve_stack()
	_band_attack([infantry.id, bear.id], {giant.id: infantry.id})
	g.priority_player = 0
	assert_ok(g.activate_ability(0, coils, 0))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "blocking the band is blocking the Bears")


func test_coils_of_the_medusa_still_spares_a_blocking_wall() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var coils := give_hand(0, "Coils of the Medusa")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, coils, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: bear.id, wall.id: bear.id}))
	g.priority_player = 0
	assert_ok(g.activate_ability(0, coils, 0))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)


func test_elvish_berserker_counts_the_blockers_of_its_band() -> void:
	var infantry := put_battlefield(0, "Benalish Infantry")
	var berserker := put_battlefield(0, "Elvish Berserker")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	_band_attack([infantry.id, berserker.id], {a.id: infantry.id, b.id: infantry.id})
	assert_eq(Vector2i(berserker.cur_power, berserker.cur_toughness), Vector2i(3, 3),
		"two creatures block its band, so two block it")


func test_elvish_berserker_alone_still_counts_its_own_blockers() -> void:
	var berserker := put_battlefield(0, "Elvish Berserker")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [berserker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: berserker.id, b.id: berserker.id}))
	resolve_stack()
	assert_eq(Vector2i(berserker.cur_power, berserker.cur_toughness), Vector2i(3, 3))


func test_wall_of_nets_exiles_every_member_of_the_band_it_blocked() -> void:
	var infantry := put_battlefield(0, "Benalish Infantry")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Nets")
	_band_attack([infantry.id, bear.id], {wall.id: infantry.id})
	advance_to_step(Mtg.Step.MAIN2)
	resolve_stack()
	assert_eq(infantry.zone, Mtg.Zone.EXILE)
	assert_eq(bear.zone, Mtg.Zone.EXILE)


# ------------------------------------------------- removed from combat --

func test_wall_of_nets_spares_an_attacker_reconnaissance_removed() -> void:
	var recon := put_battlefield(0, "Reconnaissance")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Nets")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	g.priority_player = 0
	assert_ok(g.activate_ability(0, recon, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "no longer blocked by the Wall (CR 506.4)")


func test_wall_of_nets_still_exiles_the_attacker_it_blocks() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Nets")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	advance_to_step(Mtg.Step.MAIN2)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE)


func test_kjeldoran_frostbeast_spares_an_attacker_that_regenerated_out_of_its_block() -> void:
	var skeletons := _skeletons_regenerate_out_of("Kjeldoran Frostbeast")
	assert_eq(skeletons.zone, Mtg.Zone.BATTLEFIELD)


func test_kjeldoran_frostbeast_still_destroys_the_creature_it_blocks() -> void:
	var bear := put_battlefield(0, "Hipparion")   # 1/3: survives the 2 damage
	var beast := put_battlefield(1, "Kjeldoran Frostbeast")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {beast.id: bear.id}))
	advance_to_step(Mtg.Step.MAIN2)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_dread_wight_does_not_paralyse_an_attacker_that_regenerated_out_of_its_block() -> void:
	var skeletons := _skeletons_regenerate_out_of("Dread Wight")
	assert_eq(int(skeletons.counters.get("paralyzation", 0)), 0)


func test_greater_werewolf_does_not_shrink_an_attacker_that_regenerated_out_of_its_block() -> void:
	var skeletons := _skeletons_regenerate_out_of("Greater Werewolf")
	assert_eq(skeletons.zone, Mtg.Zone.BATTLEFIELD, "no -0/-2 counter on the 1/1")
	assert_eq(int(skeletons.counters.get("-0/-2", 0)), 0)


## Player 0's Grizzly Bears attack into player 1's [param blocker_name];
## Reconnaissance then removes the Bears from combat.
func _bears_removed_from_the_block_of(blocker_name: String) -> Array:
	var recon := put_battlefield(0, "Reconnaissance")
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, blocker_name)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: bear.id}))
	g.priority_player = 0
	assert_ok(g.activate_ability(0, recon, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(g.combat.attackers.has(bear.id), "Reconnaissance removed it")
	g.priority_player = 1
	return [bear, blocker]


func test_goblin_snowman_cannot_ping_an_attacker_no_longer_blocked() -> void:
	var pair := _bears_removed_from_the_block_of("Goblin Snowman")
	assert_refused(g.activate_ability(1, pair[1], 0, [TargetRef.card(pair[0])]))


func test_wall_of_corpses_cannot_destroy_an_attacker_no_longer_blocked() -> void:
	var pair := _bears_removed_from_the_block_of("Wall of Corpses")
	add_mana(1, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(1, pair[1], 0, [TargetRef.card(pair[0])]))
	assert_eq(pair[0].zone, Mtg.Zone.BATTLEFIELD)


func test_tinder_wall_still_burns_the_attacker_it_blocks() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Tinder Wall")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	g.priority_player = 1
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(1, wall, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- Blood Frenzy --

## White Knight (first strike) attacks into Grizzly Bears, so the combat
## has a first-strike damage step.
func _first_strike_combat() -> CardInstance:
	var knight := put_battlefield(0, "White Knight")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [knight.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: knight.id}))
	return knight


func test_blood_frenzy_is_refused_in_the_first_strike_damage_step() -> void:
	var knight := _first_strike_combat()
	advance_to_step(Mtg.Step.FIRST_STRIKE_DAMAGE)
	var frenzy := give_hand(0, "Blood Frenzy")
	g.priority_player = 0
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(0, frenzy, [TargetRef.card(knight)]))


func test_blood_frenzy_is_still_castable_once_blockers_are_declared() -> void:
	var knight := _first_strike_combat()
	var frenzy := give_hand(0, "Blood Frenzy")
	g.priority_player = 0
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, frenzy, [TargetRef.card(knight)]))
	resolve_stack()
	assert_eq(knight.cur_power, 6)
