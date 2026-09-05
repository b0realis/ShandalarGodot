extends GameTest
## Wave-11 tests: the five Wards (protection auras whose own grant doesn't
## evict them — CR 702.16d exemption as printed), Lance, Blessing, the
## upkeep-sting auras (Cursed Land, Feedback), Orcish Oriflamme's
## attack-only anthem, and the block-restriction auras (Fear,
## Invisibility).


# -------------------------------------------------------------------- wards --

func test_white_ward_grants_protection_and_stays_attached() -> void:
	# White Ward is a WHITE aura granting pro-WHITE: "This effect doesn't
	# remove this Aura" — the SBA must not sweep it off its own host.
	var bear := put_battlefield(0, "Grizzly Bears")
	var ward := give_hand(0, "White Ward")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD, "the ward survives its own grant")
	assert_eq(ward.attached_to, bear.id)
	assert_true((bear.cur_protection & Mtg.ManaColor.W) != 0)
	# The T of DEBT: white removal can no longer target the bear.
	var swords := give_hand(0, "Swords to Plowshares")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, swords, [TargetRef.card(bear)]), "Illegal target")


func test_red_ward_prevents_red_damage() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var ward := give_hand(0, "Red Ward")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(bear)]))
	resolve_stack()
	# Bolt can't even target it (T); engine-level red damage bounces (D).
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(bear)]), "Illegal target")
	var dragon := put_battlefield(1, "Shivan Dragon")
	g.deal_damage(dragon, TargetRef.card(bear), 5)
	assert_eq(bear.damage, 0, "red damage prevented (D of DEBT)")


func test_other_protection_still_removes_a_ward() -> void:
	# Red Ward (a WHITE aura) falls off when the host gains pro-WHITE from
	# another source — only its OWN grant is exempt.
	var bear := put_battlefield(0, "Grizzly Bears")
	var red_ward := give_hand(0, "Red Ward")
	var white_ward := give_hand(0, "White Ward")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, red_ward, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.cast_spell(0, white_ward, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(white_ward.zone, Mtg.Zone.BATTLEFIELD, "white ward exempt from itself")
	assert_eq(red_ward.zone, Mtg.Zone.GRAVEYARD,
		"pro-white evicts the (white) Red Ward — CR 702.16d")


func test_black_ward_blanks_terror() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var ward := give_hand(0, "Black Ward")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(bear)]))
	resolve_stack()
	var terror := give_hand(1, "Terror")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B)
	assert_refused(g.cast_spell(1, terror, [TargetRef.card(bear)]), "Illegal target")


func test_blue_and_green_wards_load() -> void:
	# Cycle-completeness: both register and carry the right grant.
	var bear := put_battlefield(0, "Grizzly Bears")
	var blue := give_hand(0, "Blue Ward")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, blue, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true((bear.cur_protection & Mtg.ManaColor.U) != 0)
	var lions := put_battlefield(0, "Savannah Lions")
	var green := give_hand(0, "Green Ward")
	assert_ok(g.cast_spell(0, green, [TargetRef.card(lions)]))
	resolve_stack()
	assert_true((lions.cur_protection & Mtg.ManaColor.G) != 0)


# ---------------------------------------------------------- Lance & Blessing --

func test_lance_grants_first_strike() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var lance := give_hand(0, "Lance")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, lance, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_blessing_pumps_the_host_per_white_mana() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var blessing := give_hand(0, "Blessing")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 4)
	assert_ok(g.cast_spell(0, blessing, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, blessing, 0, []))
	assert_ok(g.activate_ability(0, blessing, 0, []))
	resolve_stack()
	assert_eq(bear.cur_power, 4, "2 + two +1/+1 pumps")
	assert_eq(bear.cur_toughness, 4)


# ------------------------------------------------- upkeep stings (auras) --

func test_cursed_land_stings_the_lands_controller() -> void:
	var swamp := put_battlefield(1, "Swamp")
	var curse := give_hand(0, "Cursed Land")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, curse, [TargetRef.card(swamp)]))
	resolve_stack()
	advance_to_step(Mtg.Step.UPKEEP)   # turn 2: the OPPONENT's upkeep
	resolve_stack()
	assert_eq(g.players[1].life, 19, "1 damage at the enchanted land's controller's upkeep")
	assert_eq(g.players[0].life, 20)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)   # turn 3: OUR upkeep — no sting
	resolve_stack()
	assert_eq(g.players[1].life, 19, "no sting on the caster's upkeep")
	assert_eq(g.players[0].life, 20)


func test_cursed_land_refuses_creatures() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var curse := give_hand(0, "Cursed Land")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, curse, [TargetRef.card(bear)]), "Illegal target")


func test_feedback_stings_the_enchantments_controller() -> void:
	put_battlefield(1, "Crusade")
	var crusade := g.find_on_battlefield(1, "Crusade")
	var feedback := give_hand(0, "Feedback")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, feedback, [TargetRef.card(crusade)]))
	resolve_stack()
	advance_to_step(Mtg.Step.UPKEEP)   # the opponent's upkeep
	resolve_stack()
	assert_eq(g.players[1].life, 19)


# --------------------------------------------------------- Orcish Oriflamme --

func test_oriflamme_boosts_only_attackers() -> void:
	put_battlefield(0, "Orcish Oriflamme")
	var bear := put_battlefield(0, "Grizzly Bears")
	var home := put_battlefield(0, "Savannah Lions")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_eq(bear.cur_power, 3, "attacking: +1/+0")
	assert_eq(bear.cur_toughness, 2)
	assert_eq(home.cur_power, 2, "staying home: no boost")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(bear.cur_power, 2, "combat over — boost gone")
	assert_eq(g.players[1].life, 17, "3 combat damage got through")


# ------------------------------------------------------- Fear & Invisibility --

func test_fear_restricts_blockers() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var fear := give_hand(0, "Fear")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, fear, [TargetRef.card(bear)]))
	resolve_stack()
	var enemy_bear := put_battlefield(1, "Grizzly Bears")
	var zombies := put_battlefield(1, "Scathe Zombies")
	var wall := put_battlefield(1, "Living Wall")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {enemy_bear.id: bear.id}), "fear")
	assert_ok(g.declare_blockers(1, {zombies.id: bear.id, wall.id: bear.id}))


func test_invisibility_only_walls_block() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var cloak := give_hand(0, "Invisibility")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, cloak, [TargetRef.card(bear)]))
	resolve_stack()
	var enemy_bear := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {enemy_bear.id: bear.id}), "except by")
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
