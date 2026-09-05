extends GameTest
## Wave-73 tests: the DAMAGE-REPLACEMENT cluster, and the shared piece it
## was waiting on — MtgPlayer.damage_replacements, the one-shot (or
## all-turn) "the next time a source of your choice would deal damage to you
## this turn, instead ..." list, applied before every prevention gate
## because a replacement comes first (CR 614/616). The engine tests for the
## list itself live in tests/unit/test_engine_additions.gd.


## Picks a CARD by name, else the first candidate; says yes to everything.
class Picker extends DecisionAgent:
	var wanted := ""

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return true

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null if candidates.is_empty() else candidates[0]


## Refuses every offer.
class Reluctant extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return false


func test_registry_loaded_wave73() -> void:
	for name in ["Forcefield", "Dark Sphere", "Eye for an Eye",
			"Nova Pentacle", "Shimian Night Stalker", "Blood of the Martyr",
			"Silhouette", "Reverberation", "Personal Incarnation",
			"Rock Hydra"]:
		assert_not_null(CardRegistry.get_card(name), name)


func test_every_stub_has_graduated() -> void:
	# cards/todo/ is empty: the pool is complete but for the four cards
	# excluded on physical grounds (Chaos Orb, Falling Star, Shahrazad,
	# Word of Command).
	assert_eq(DirAccess.get_directories_at("res://cards/todo").size(), 8,
		"the set folders are still there")
	for set_code in DirAccess.get_directories_at("res://cards/todo"):
		var left := DirAccess.get_files_at("res://cards/todo/%s" % set_code)
		var stubs := 0
		for f in left:
			if f.ends_with(".gd"):
				stubs += 1
		assert_eq(stubs, 0, "no stubs left in cards/todo/%s" % set_code)


# ------------------------------------------------------------- Forcefield --

func test_forcefield_leaves_one_point_through() -> void:
	var agent := Picker.new()
	agent.wanted = "Hill Giant"
	g.set_agent(0, agent)
	put_battlefield(0, "Forcefield")
	var giant := put_battlefield(1, "Hill Giant")      # 3/3
	advance_to_next_turn()                             # p1's turn
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C)
	var field := g.find_on_battlefield(0, "Forcefield")
	assert_ok(g.activate_ability(0, field, 0))
	resolve_stack()
	run_combat([giant.id])
	assert_eq(g.players[0].life, 19, "all but 1 was prevented")


func test_forcefield_does_nothing_to_a_blocked_attacker() -> void:
	var agent := Picker.new()
	agent.wanted = "Hill Giant"
	g.set_agent(0, agent)
	put_battlefield(0, "Forcefield")
	var wall := put_battlefield(0, "Wall of Wood")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C)
	var field := g.find_on_battlefield(0, "Forcefield")
	assert_ok(g.activate_ability(0, field, 0))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {wall.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "nothing got through anyway")
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "the wall took the full 3")


# ------------------------------------------------------------ Dark Sphere --

func test_dark_sphere_halves_the_next_damage_rounded_down() -> void:
	var agent := Picker.new()
	agent.wanted = "Lightning Bolt"
	g.set_agent(0, agent)
	var sphere := put_battlefield(0, "Dark Sphere")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, sphere, 0))
	resolve_stack()
	assert_eq(sphere.zone, Mtg.Zone.GRAVEYARD, "sacrificed as a cost")
	assert_eq(g.players[0].life, 18, "3 halved to 1 prevented, 2 through")


# --------------------------------------------------------- Eye for an Eye --

func test_eye_for_an_eye_mirrors_the_damage_back() -> void:
	var agent := Picker.new()
	agent.wanted = "Lightning Bolt"
	g.set_agent(0, agent)
	var bolt := give_hand(1, "Lightning Bolt")
	var eye := give_hand(0, "Eye for an Eye")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, eye, []))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "you still take it")
	assert_eq(g.players[1].life, 17, "and so do they")


# --------------------------------------------------------- Nova Pentacle --

func test_nova_pentacle_deflects_onto_their_own_creature() -> void:
	var agent := Picker.new()
	agent.wanted = "Lightning Bolt"
	g.set_agent(0, agent)
	var pentacle := put_battlefield(0, "Nova Pentacle")
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, pentacle, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "it never reached you")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "their own creature ate it")


func test_nova_pentacle_cannot_be_activated_with_no_creature_to_deflect_onto() -> void:
	# The creature is a TARGET of the opponent's choice (lifted 2026-09-02):
	# with none on the battlefield the ability can't be activated (CR 601.2c).
	var agent := Picker.new()
	agent.wanted = "Lightning Bolt"
	g.set_agent(0, agent)
	var pentacle := put_battlefield(0, "Nova Pentacle")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, pentacle, 0), "no legal target")
	resolve_stack()
	assert_eq(g.players[0].life, 17, "nowhere to send it")


# -------------------------------------------------- Shimian Night Stalker --

func test_shimian_night_stalker_takes_every_blow_that_attacker_deals() -> void:
	var stalker := put_battlefield(0, "Shimian Night Stalker")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {}))
	assert_ok(g.pass_priority(1))   # p0 acts in the blockers step
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, stalker, 0, [TargetRef.card(giant)]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "it never reached you")
	assert_eq(stalker.damage, 3, "the Stalker took it")


# ------------------------------------------------------ Blood of the Martyr --

func test_blood_of_the_martyr_lets_you_take_a_creatures_damage() -> void:
	g.set_agent(0, Picker.new())
	var bear := put_battlefield(0, "Grizzly Bears")
	var blood := give_hand(0, "Blood of the Martyr")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, blood, []))
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the bear lived")
	assert_eq(g.players[0].life, 17, "you took it instead")


func test_blood_of_the_martyr_is_declinable_per_packet() -> void:
	g.set_agent(0, Reluctant.new())
	var bear := put_battlefield(0, "Grizzly Bears")
	var blood := give_hand(0, "Blood of the Martyr")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, blood, []))
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)


# ------------------------------------------------------------- Silhouette --

func test_silhouette_stops_a_targeted_burn_spell() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var fade := give_hand(0, "Silhouette")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, fade, [TargetRef.card(bear)]))
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.damage, 0, "the spell targeted it, so it was prevented")


func test_silhouette_does_nothing_to_combat_damage() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var fade := give_hand(0, "Silhouette")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, fade, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {bear.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "combat damage is not a spell")


# ---------------------------------------------------------- Reverberation --

func test_reverberation_turns_a_sorcery_on_its_caster() -> void:
	var quake := give_hand(1, "Earthquake")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(1, quake, [], 3))
	assert_ok(g.pass_priority(1))
	var reverb := give_hand(0, "Reverberation")
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, reverb, [TargetRef.card(quake)]))
	resolve_stack()
	# Earthquake would have hit both players for 3; every point goes to p1.
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[1].life, 14)


# ------------------------------------------------- Personal Incarnation --

func test_personal_incarnation_sends_damage_to_its_owner() -> void:
	var avatar := put_battlefield(0, "Personal Incarnation")
	assert_ok(g.activate_ability(0, avatar, 0))
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(avatar)]))
	resolve_stack()
	# Lifted 2026-09-02 (was a GAP pinned here since 2026-09-01): the
	# printed line moves "the next ONE damage", so a Lightning Bolt puts 1
	# on the owner and leaves 2 marked on the Avatar — a METERED redirect
	# (CardInstance.damage_point_redirects, DamagePacket.divert), not Jade
	# Monolith's whole-event one.
	assert_eq(avatar.damage, 2, "only 1 point moves and 2 stay on the Avatar")
	assert_eq(g.players[0].life, 19, "the owner takes 1, not 3")


func test_personal_incarnation_answers_only_to_its_owner() -> void:
	var avatar := put_battlefield(0, "Personal Incarnation")
	g.change_control(avatar, 1)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, avatar, 0), "only its owner")


func test_personal_incarnation_costs_its_owner_half_on_death() -> void:
	var avatar := put_battlefield(0, "Personal Incarnation")
	g.destroy(avatar)
	resolve_stack()
	assert_eq(g.players[0].life, 10, "half of 20, rounded up")


# ------------------------------------------------------------ Rock Hydra --

func test_rock_hydra_enters_with_x_heads() -> void:
	var hydra := give_hand(0, "Rock Hydra")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, hydra, [], 3))
	resolve_stack()
	assert_eq(hydra.zone, Mtg.Zone.BATTLEFIELD, "never a 0/0 for the SBAs")
	assert_eq(hydra.cur_power, 3)
	assert_eq(hydra.cur_toughness, 3)


func test_rock_hydra_sheds_a_head_for_each_point_of_damage() -> void:
	var hydra := give_hand(0, "Rock Hydra")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, hydra, [], 4))
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(hydra)]))
	resolve_stack()
	assert_eq(int(hydra.counters.get("+1/+1", 0)), 1, "three heads eaten")
	assert_eq(hydra.damage, 0, "and all three points prevented")
	assert_eq(hydra.cur_toughness, 1)


func test_rock_hydra_dies_when_the_heads_run_out() -> void:
	var hydra := give_hand(0, "Rock Hydra")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, hydra, [], 2))
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(hydra)]))
	resolve_stack()
	assert_eq(hydra.zone, Mtg.Zone.GRAVEYARD,
		"two heads eaten, the third point kills a 0/0")


func test_rock_hydra_regrows_only_in_your_upkeep() -> void:
	var hydra := put_battlefield(0, "Rock Hydra")
	g.add_counters(hydra, "+1/+1", 1)
	advance_to_step(Mtg.Step.MAIN1)   # out of turn 1's own upkeep
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_refused(g.activate_ability(0, hydra, 1), "upkeep")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.activate_ability(0, hydra, 1))
	resolve_stack()
	assert_eq(int(hydra.counters.get("+1/+1", 0)), 2)
