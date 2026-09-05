extends GameTest
## Engine tests for the wave-1 mechanics: first strike, protection (DEBT),
## regeneration, landwalk, must-attack, wall-bans, counterspells, X-spells,
## and sacrifice mana abilities — each exercised through real pool cards.


# ------------------------------------------------------------ first strike --

func test_first_strike_kills_before_counterdamage() -> void:
	# White Knight (2/2 first strike) blocked by Grizzly Bears (2/2):
	# the bear dies in the first-strike wave and never hits back.
	var knight := put_battlefield(0, "White Knight")
	var bear := put_battlefield(1, "Grizzly Bears")
	run_combat([knight.id], {bear.id: knight.id})
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(knight.damage, 0, "dead blockers deal no damage")


func test_first_strike_mirror_trades_simultaneously() -> void:
	# Elvish Archers vs Elvish Archers (both 2/1 first strike): both strike
	# in the same wave and trade.
	var mine := put_battlefield(0, "Elvish Archers")
	var theirs := put_battlefield(1, "Elvish Archers")
	run_combat([mine.id], {theirs.id: mine.id})
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------- protection (DEBT) --

func test_protection_cant_be_targeted() -> void:
	# Terror (black) cannot target White Knight; Swords (white) cannot
	# target Black Knight.
	var wk := put_battlefield(1, "White Knight")
	var bk := put_battlefield(1, "Black Knight")
	var terror := give_hand(0, "Terror")
	var swords := give_hand(0, "Swords to Plowshares")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, terror, [TargetRef.card(wk)]), "Illegal target")
	assert_refused(g.cast_spell(0, swords, [TargetRef.card(bk)]), "Illegal target")


func test_protection_cant_be_blocked_by() -> void:
	# Black Knight can't be blocked by white Savannah Lions.
	var bk := put_battlefield(0, "Black Knight")
	var lions := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bk.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {lions.id: bk.id}), "protection")


func test_protection_prevents_damage() -> void:
	# The D of DEBT, isolated: black-source damage to White Knight is
	# prevented outright (engine-level check, no combat noise).
	var wk := put_battlefield(0, "White Knight")
	var zombies := put_battlefield(1, "Scathe Zombies")
	g.deal_damage(zombies, TargetRef.card(wk), 2)
	assert_eq(wk.damage, 0, "black damage prevented by protection")
	# And in combat: the zombies attack (on THEIR controller's turn), the
	# knight blocks — legal in this direction (the BLOCKED creature's
	# protection is what bans blockers). First strike kills the zombies in
	# wave 1; the knight ends unscratched.
	advance_to_next_turn()   # P1 becomes the active player
	run_combat([zombies.id], {wk.id: zombies.id})
	assert_eq(zombies.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wk.damage, 0)


func test_protection_cant_be_enchanted() -> void:
	# Unholy Strength (black aura) cannot enchant White Knight.
	var wk := put_battlefield(0, "White Knight")
	var aura := give_hand(0, "Unholy Strength")
	advance_to_step(Mtg.Step.MAIN1)   # enchantments are sorcery-speed
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.cast_spell(0, aura, [TargetRef.card(wk)]), "Illegal target")


# ------------------------------------------------------------ regeneration --

func test_regeneration_saves_from_lethal_damage() -> void:
	var skeletons := put_battlefield(0, "Drudge Skeletons")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	# Build a shield first, then let the bolt hit.
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, skeletons, 0, []))
	resolve_stack()
	assert_eq(skeletons.regeneration_shields, 1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(skeletons)]))
	resolve_stack()
	assert_eq(skeletons.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(skeletons.tapped, "regeneration taps")
	assert_eq(skeletons.damage, 0, "regeneration clears damage")
	assert_eq(skeletons.regeneration_shields, 0, "shield consumed")


func test_terror_ignores_regeneration_shields() -> void:
	# Shields on a GREEN creature (Terror can't target black ones — the
	# engine rightly refused the first draft of this test): the "can't be
	# regenerated" rider blows straight through them.
	var bear := put_battlefield(1, "Grizzly Bears")
	bear.regeneration_shields = 2
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "'can't be regenerated' is real")


# ---------------------------------------------------------------- landwalk --

func test_swampwalk_unblockable_while_defender_has_swamp() -> void:
	var wraith := put_battlefield(0, "Bog Wraith")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Swamp")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wraith.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: wraith.id}), "swampwalk")


func test_swampwalk_sees_dual_lands() -> void:
	# Underground Sea has the swamp SUBTYPE — the wraith walks through it.
	var wraith := put_battlefield(0, "Bog Wraith")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Underground Sea")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wraith.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: wraith.id}), "swampwalk")


func test_no_swamp_no_walk() -> void:
	var wraith := put_battlefield(0, "Bog Wraith")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Forest")
	run_combat([wraith.id], {bear.id: wraith.id})
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "block was legal; 3 power kills the bear")
	assert_eq(g.players[1].life, 20)


# ---------------------------------------------- must-attack & wall bans --

func test_juggernaut_must_attack() -> void:
	var juggs := put_battlefield(0, "Juggernaut")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, []), "attacks each combat")
	assert_ok(g.declare_attackers(0, [juggs.id]))


func test_tapped_juggernaut_excuses_the_requirement() -> void:
	var juggs := put_battlefield(0, "Juggernaut")
	juggs.tapped = true
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []), )


func test_wall_cannot_block_juggernaut() -> void:
	var juggs := put_battlefield(0, "Juggernaut")
	var wall := put_battlefield(1, "Wall of Stone")   # 0/8 defender wall
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [juggs.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: juggs.id}), "wall")


# ------------------------------------------------------------ counterspell --

func test_counterspell_counters_a_creature_spell() -> void:
	var bears := give_hand(0, "Grizzly Bears")
	var counter := give_hand(1, "Counterspell")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, bears, []))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "countered — never hit the battlefield")
	assert_eq(g.players[0].battlefield.size(), 0)


func test_counter_war_lets_the_bolt_through() -> void:
	# P0 bolts P1; P1 counters the bolt; P0 counters the Counterspell.
	# LIFO: counter2 kills counter1, then the bolt resolves.
	var bolt := give_hand(0, "Lightning Bolt")
	var counter1 := give_hand(1, "Counterspell")
	var counter2 := give_hand(0, "Counterspell")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, counter1, [TargetRef.card(bolt)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.cast_spell(0, counter2, [TargetRef.card(counter1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17, "the bolt resolved")
	assert_eq(counter1.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------ X and Lotus --

func test_fireball_x_kills_a_four_toughness_creature() -> void:
	var serra := put_battlefield(1, "Serra Angel")
	var fireball := give_hand(0, "Fireball")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.cast_spell(0, fireball, [TargetRef.card(serra)], 5),
		"not enough mana")   # X=5 needs 5 generic; only 4 floating
	assert_ok(g.cast_spell(0, fireball, [TargetRef.card(serra)], 4))
	resolve_stack()
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD, "X=4 kills the 4/4")


func test_black_lotus_sacrifices_for_three() -> void:
	var lotus := give_hand(0, "Black Lotus")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.cast_spell(0, lotus, []))   # {0} — free
	resolve_stack()
	assert_ok(g.tap_for_mana(0, lotus, 3))   # index 3 = red
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 3)
	assert_eq(lotus.zone, Mtg.Zone.GRAVEYARD, "sacrificed as part of the cost")


func test_dual_land_offers_both_colors() -> void:
	var tundra := put_battlefield(0, "Tundra")
	assert_ok(g.tap_for_mana(0, tundra, 1))   # index 1 = blue
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.W), 0)
