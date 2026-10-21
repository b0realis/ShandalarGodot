extends GameTest
## THE OWNER'S RULING OF 2026-10-21 ON DIVIDED DAMAGE, verbatim: *"how
## Fireball divides its damage when one of its targets is gone (it is
## ignored if target dissapears - the spell crushes empty space :))"*.
##
## A spell that divides damage among targets divides it AS IT IS CAST
## (CR 601.2d), among ALL the targets chosen; a target that is gone or
## illegal on resolution simply loses its share (CR 608.2b) — nobody else
## gets it — and with every target gone the spell does nothing.
##
## WAS: Fireball (`cards/sets/2ed/fireball.gd`) divided X among the
## targets still legal on resolution, so a target bounced or killed in
## response DOUBLED the damage to the other one. NOW it divides among the
## targets chosen ([method MtgGame.chosen_target_count]).
##
## The "divided as you choose" family already kept each target's share on
## its own ref ([member TargetRef.amount], fixed by TargetPlan as the spell
## is cast); these pin it, card by card, so the rule cannot drift:
## Pyrotechnics, Pyrokinesis, Fiery Justice, Fire Covenant, Meteor Shower,
## Forked Lightning, Rolling Thunder, Infernal Harvest, Rock Slide — and
## Remedy, which divides damage PREVENTION the same way.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	for id in [IceAgePack.ID, "pack-5", "pack-6", "pack-8", "pack-9"]:
		CardPacks.set_enabled(id, true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _fund(pid: int, card: CardInstance, x := 0, extra := 0) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	var generic := cost.generic + x * cost.x_count + extra
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)


# ================================================================ Fireball --

func test_fireball_target_bounced_in_response_takes_its_share_away() -> void:
	# X=6 at a Hill Giant and the opponent: 3 each. The opponent Unsummons
	# their Giant in response — they take 3, not 6.
	var giant := put_battlefield(1, "Hill Giant")
	var fireball := give_hand(0, "Fireball")
	_fund(0, fireball, 6, 1)                      # {1} for the second target
	assert_ok(g.cast_spell(0, fireball, [TargetRef.card(giant), TargetRef.player(1)], 6))
	assert_ok(g.pass_priority(0))
	var unsummon := give_hand(1, "Unsummon")
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, unsummon, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.HAND, "the Giant went home")
	assert_eq(g.players[1].life, 17, "the player takes only their share, 3 of 6")
	assert_eq(fireball.zone, Mtg.Zone.GRAVEYARD)


func test_fireball_target_killed_in_response_takes_its_share_away() -> void:
	# X=4 at a Grizzly Bears and the opponent: 2 each. The Bears die first.
	var bear := put_battlefield(1, "Grizzly Bears")
	var fireball := give_hand(0, "Fireball")
	_fund(0, fireball, 4, 1)
	assert_ok(g.cast_spell(0, fireball, [TargetRef.card(bear), TargetRef.player(1)], 4))
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18, "2 to the player, not the whole 4")


func test_fireball_rounds_the_share_of_the_targets_chosen() -> void:
	# X=5 among three targets is 1 each (5/3 rounded down) — still 1 each
	# with one of them gone, never 5/2 = 2.
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var fireball := give_hand(0, "Fireball")
	_fund(0, fireball, 5, 2)
	assert_ok(g.cast_spell(0, fireball,
		[TargetRef.card(bear), TargetRef.card(giant), TargetRef.player(1)], 5))
	g.return_to_hand(bear)                        # gone in response
	resolve_stack()
	assert_eq(giant.damage, 1)
	assert_eq(g.players[1].life, 19)


func test_fireball_with_every_target_gone_does_nothing() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var fireball := give_hand(0, "Fireball")
	_fund(0, fireball, 6, 1)
	assert_ok(g.cast_spell(0, fireball, [TargetRef.card(bear), TargetRef.card(giant)], 6))
	g.return_to_hand(bear)
	g.return_to_hand(giant)
	resolve_stack()
	assert_eq(fireball.zone, Mtg.Zone.GRAVEYARD, "it fizzled")
	assert_eq([bear.damage, giant.damage], [0, 0])
	assert_eq([g.players[0].life, g.players[1].life], [20, 20], "the empty space is crushed")


func test_fireball_with_every_target_still_there_is_unchanged() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var fireball := give_hand(0, "Fireball")
	_fund(0, fireball, 6, 1)
	assert_ok(g.cast_spell(0, fireball, [TargetRef.card(giant), TargetRef.player(1)], 6))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "3 kills the 3/3")
	assert_eq(g.players[1].life, 17)


func test_chosen_target_count_is_zero_outside_a_resolution() -> void:
	assert_eq(g.chosen_target_count(), 0)


# ======================================= the "divided as you choose" family --
# Each: two targets with a chosen division, the larger share's target gone
# before resolution — the other target takes exactly ITS share.

func test_pyrotechnics_keeps_each_share() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var pyro := give_hand(0, "Pyrotechnics")
	_fund(0, pyro)
	assert_ok(g.cast_spell(0, pyro, [TargetRef.card(bear, 3), TargetRef.player(1, 1)]))
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(g.players[1].life, 19, "1, the player's share — not 4")


func test_pyrokinesis_keeps_each_share() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var spell := give_hand(0, "Pyrokinesis")
	_fund(0, spell)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear, 3), TargetRef.card(giant, 1)]))
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(giant.damage, 1)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


func test_fiery_justice_keeps_each_share() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Fiery Justice")
	_fund(0, spell)
	assert_ok(g.cast_spell(0, spell,
		[TargetRef.card(bear, 3), TargetRef.player(1, 2), TargetRef.player(1)]))
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(g.players[1].life, 23, "20 - 2 + 5: the Bear's 3 went nowhere")


func test_fire_covenant_keeps_each_share() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var spell := give_hand(0, "Fire Covenant")
	_fund(0, spell)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear, 3), TargetRef.card(giant, 1)], 4))
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(giant.damage, 1)
	assert_eq(g.players[0].life, 16, "the life was paid as it was cast")


func test_meteor_shower_keeps_each_share() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Meteor Shower")
	_fund(0, spell, 2)                            # X=2: 3 damage
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear, 2), TargetRef.player(1, 1)], 2))
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(g.players[1].life, 19)


func test_forked_lightning_keeps_each_share() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var spell := give_hand(0, "Forked Lightning")
	_fund(0, spell)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear, 3), TargetRef.card(giant, 1)]))
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(giant.damage, 1)


func test_rolling_thunder_keeps_each_share() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Rolling Thunder")
	_fund(0, spell, 4)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear, 3), TargetRef.player(1, 1)], 4))
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(g.players[1].life, 19)


func test_infernal_harvest_keeps_each_share() -> void:
	for _i in 3: put_battlefield(0, "Swamp")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var spell := give_hand(0, "Infernal Harvest")
	_fund(0, spell)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear, 2), TargetRef.card(giant, 1)], 3))
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(giant.damage, 1)


func test_rock_slide_keeps_each_share() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id, giant.id]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	var spell := give_hand(1, "Rock Slide")
	_fund(1, spell, 3)
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(bear, 2), TargetRef.card(giant, 1)], 3))
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(giant.damage, 1)


func test_remedy_keeps_each_share_of_prevention() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var spell := give_hand(1, "Remedy")
	_fund(1, spell)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(giant, 3), TargetRef.player(1, 2)]))
	g.return_to_hand(giant)
	resolve_stack()
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19, "2 of the 3 prevented — the Giant's 3 went nowhere")
