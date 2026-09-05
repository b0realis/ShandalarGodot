extends GameTest
## "BANDS WITH OTHER [quality]" (CR 702.22c, second sentence; 702.22b;
## 702.22j-k), lifted 2026-09-02 — docs/simplified-cards.md row "Banding
## lands and bands-with cycles". Until then the five Legends lands
## granted plain BANDING, so a legend could band with anything and could
## not lead a band of two more legends.
##
## Adventurers' Guildhouse: green legendary creatures you control have
## "bands with other legendary creatures". Jasmine Boreal, Kei Takahashi
## and Ragnar are green legends (granted); Axelrod Gunnarson and Barktooth
## Warbeard are legends without green (nothing granted, no banding of
## their own); Grizzly Bears is nobody's legend.
##
## The same lift covers Master of the Hunt, whose Wolves of the Hunt
## tokens carry the ability themselves (a static that grants the token
## "bands with other creatures named Wolves of the Hunt") instead of the
## plain BANDING they used to be printed with.


func _band(ids: Array) -> String:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	return g.declare_attackers(0, ids, [ids])


func test_a_granted_legend_bands_with_another_legend() -> void:
	put_battlefield(0, "Adventurers' Guildhouse")
	var jasmine := put_battlefield(0, "Jasmine Boreal")
	var axelrod := put_battlefield(0, "Axelrod Gunnarson")
	assert_false(jasmine.has_keyword(Mtg.Keyword.BANDING),
		"'bands with other' is not banding (CR 702.22c: 'even if it has bands with other')")
	assert_ok(_band([jasmine.id, axelrod.id]))
	assert_eq(g.combat.bands.size(), 1)


func test_a_granted_legend_leads_a_band_of_three_legends() -> void:
	# "One or more attacking [quality] creatures with 'bands with other
	# [quality]' and ANY NUMBER of other attacking [quality] creatures" —
	# plain banding would allow only one creature without banding.
	put_battlefield(0, "Adventurers' Guildhouse")
	var jasmine := put_battlefield(0, "Jasmine Boreal")
	var axelrod := put_battlefield(0, "Axelrod Gunnarson")
	var barktooth := put_battlefield(0, "Barktooth Warbeard")
	assert_ok(_band([jasmine.id, axelrod.id, barktooth.id]))
	assert_eq(g.combat.band_of(barktooth.id).size(), 3)


func test_a_granted_legend_does_not_band_with_a_non_legend() -> void:
	put_battlefield(0, "Adventurers' Guildhouse")
	var jasmine := put_battlefield(0, "Jasmine Boreal")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_refused(_band([jasmine.id, bears.id]), "bands with other")


func test_two_granted_legends_band_together() -> void:
	put_battlefield(0, "Adventurers' Guildhouse")
	var jasmine := put_battlefield(0, "Jasmine Boreal")
	var kei := put_battlefield(0, "Kei Takahashi")
	assert_ok(_band([jasmine.id, kei.id]))


func test_plain_banding_still_takes_one_creature_without_it() -> void:
	# The first form of CR 702.22c is untouched.
	var hero := put_battlefield(0, "Benalish Hero")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_ok(_band([hero.id, bears.id]))


func test_tolaria_strips_bands_with_other_as_well() -> void:
	# CR 702.22b: "If an effect causes a permanent to lose banding, the
	# permanent loses all 'bands with other' abilities as well."
	put_battlefield(0, "Adventurers' Guildhouse")
	var tolaria := put_battlefield(0, "Tolaria")
	var jasmine := put_battlefield(0, "Jasmine Boreal")
	var axelrod := put_battlefield(0, "Axelrod Gunnarson")
	assert_eq(jasmine.cur_bands_with.size(), 1, "granted by the Guildhouse")
	assert_ok(g.activate_ability(0, tolaria, 0, [TargetRef.card(jasmine)]))
	resolve_stack()
	assert_eq(jasmine.cur_bands_with.size(), 0, "lost until end of turn")
	assert_refused(_band([jasmine.id, axelrod.id]), "banding")


func test_bands_with_other_blockers_hand_the_division_to_the_defender() -> void:
	# CR 702.22j: "both a [quality] creature with 'bands with other
	# [quality]' and another [quality] creature" blocking — the DEFENDER
	# divides the attacker's damage, freely, so a trampler spills nothing.
	var wurm := put_battlefield(0, "Craw Wurm")   # 6/4
	wurm.added_keywords.append(Mtg.Keyword.TRAMPLE)
	g.recalculate()
	put_battlefield(1, "Adventurers' Guildhouse")
	var kei := put_battlefield(1, "Kei Takahashi")   # 2/2, granted
	var ragnar := put_battlefield(1, "Ragnar")       # 2/2, granted
	run_combat([wurm.id], {kei.id: wurm.id, ragnar.id: wurm.id})
	assert_eq(g.players[1].life, 20, "the defender kept every point on a body")
	assert_true(kei.zone == Mtg.Zone.BATTLEFIELD or ragnar.zone == Mtg.Zone.BATTLEFIELD,
		"one of them walked away")


func test_a_bands_with_other_blocker_beside_a_non_legend_is_no_band() -> void:
	# The same block with Grizzly Bears instead of Ragnar: Kei's "bands
	# with other legendary creatures" has no other legend beside it, so
	# the ATTACKER assigns lethal-first and the trampler spills 2.
	var wurm := put_battlefield(0, "Craw Wurm")
	wurm.added_keywords.append(Mtg.Keyword.TRAMPLE)
	g.recalculate()
	put_battlefield(1, "Adventurers' Guildhouse")
	var kei := put_battlefield(1, "Kei Takahashi")
	var bears := put_battlefield(1, "Grizzly Bears")
	run_combat([wurm.id], {kei.id: wurm.id, bears.id: wurm.id})
	assert_eq(g.players[1].life, 18, "2 + 2 lethal, 2 tramples over")
	assert_eq(kei.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


func test_each_land_grants_its_own_colour() -> void:
	var lands := {
		"Adventurers' Guildhouse": Mtg.ManaColor.G, "Cathedral of Serra": Mtg.ManaColor.W,
		"Mountain Stronghold": Mtg.ManaColor.R, "Seafarer's Quay": Mtg.ManaColor.U,
		"Unholy Citadel": Mtg.ManaColor.B,
	}
	var jasmine := put_battlefield(0, "Jasmine Boreal")     # G W
	var axelrod := put_battlefield(0, "Axelrod Gunnarson")  # B R
	var bears := put_battlefield(0, "Grizzly Bears")        # G, not a legend
	for land_name in lands:
		var land := put_battlefield(0, land_name)
		g.recalculate()
		var color: int = lands[land_name]
		assert_eq(jasmine.cur_bands_with.size(), 1 if (jasmine.cur_colors & color) != 0 else 0,
			"%s: Jasmine" % land_name)
		assert_eq(axelrod.cur_bands_with.size(), 1 if (axelrod.cur_colors & color) != 0 else 0,
			"%s: Axelrod" % land_name)
		assert_eq(bears.cur_bands_with.size(), 0, "%s: the Bears are no legend" % land_name)
		assert_false(jasmine.has_keyword(Mtg.Keyword.BANDING), "%s grants no plain banding" % land_name)
		g.exile_permanent(land)
		g.recalculate()


# -------------------------------------- Master of the Hunt's Wolf pack --

## Activate Master of the Hunt [param n] times and return the pack, ready
## to attack (the tokens arrive this turn, so their sickness is cleared
## the way put_battlefield clears a set-up permanent's).
func _pack(n: int) -> Array[CardInstance]:
	var master := put_battlefield(0, "Master of the Hunt")
	advance_to_step(Mtg.Step.MAIN1)
	for _i in n:
		add_mana(0, Mtg.ManaColor.G, 2)
		add_mana(0, Mtg.ManaColor.C, 2)
		assert_ok(g.activate_ability(0, master, 0, []))
		resolve_stack()
	var pack: Array[CardInstance] = []
	for inst in g.all_battlefield():
		if inst.data.card_name == "Wolves of the Hunt":
			inst.summoning_sick = false
			pack.append(inst)
	return pack


func test_a_wolf_carries_bands_with_other_wolves_and_not_banding() -> void:
	var pack := _pack(1)
	assert_eq(pack.size(), 1)
	assert_false(pack[0].has_keyword(Mtg.Keyword.BANDING),
		"the token's printed ability is 'bands with other', never banding")
	assert_eq(pack[0].cur_bands_with.size(), 1)
	assert_eq(String(pack[0].cur_bands_with[0]["desc"]),
		"creatures named Wolves of the Hunt")


func test_the_whole_pack_attacks_as_one_band() -> void:
	# "Any number of other attacking [quality] creatures" — plain banding
	# allowed exactly one of the three to lack the keyword.
	var pack := _pack(3)
	assert_eq(pack.size(), 3)
	assert_ok(_band([pack[0].id, pack[1].id, pack[2].id]))
	assert_eq(g.combat.band_of(pack[0].id).size(), 3)


func test_a_wolf_does_not_band_with_its_master() -> void:
	# Master of the Hunt is a Human, not a creature named Wolves of the
	# Hunt, and has no banding of his own.
	var pack := _pack(1)
	var master := g.find_on_battlefield(0, "Master of the Hunt")
	assert_refused(_band([pack[0].id, master.id]), "bands with other")


func test_a_wolf_is_the_one_non_banding_member_a_banding_creature_may_take() -> void:
	# "Bands with other" is not banding (CR 702.22c), so under the FIRST
	# form a Wolf is simply a creature without banding: Benalish Hero may
	# take one along, and only one.
	var pack := _pack(2)
	var hero := put_battlefield(0, "Benalish Hero")
	assert_refused(_band([hero.id, pack[0].id, pack[1].id]), "bands with other")
	assert_ok(g.declare_attackers(0, [hero.id, pack[0].id], [[hero.id, pack[0].id]]))


func test_two_wolves_blocking_hand_the_division_to_the_defender() -> void:
	# CR 702.22j, the printed reminder: "If at least two creatures named
	# Wolves of the Hunt you control, one of which has 'bands with
	# other...', are blocking or being blocked by the same creature, you
	# divide that creature's combat damage" — so a trampler spills nothing.
	var pack := _pack(2)
	advance_to_next_turn()
	var wurm := put_battlefield(1, "Craw Wurm")   # 6/4
	wurm.added_keywords.append(Mtg.Keyword.TRAMPLE)
	g.recalculate()
	run_combat([wurm.id], {pack[0].id: wurm.id, pack[1].id: wurm.id})
	assert_eq(g.players[0].life, 20, "the defender kept every point on a body")
	assert_true(pack[0].zone == Mtg.Zone.BATTLEFIELD
		or pack[1].zone == Mtg.Zone.BATTLEFIELD, "one Wolf walked away")


func test_a_wolf_beside_a_non_wolf_blocker_is_no_band() -> void:
	# One Wolf and Grizzly Bears blocking the same trampler: nothing pairs
	# two Wolves, so the ATTACKER assigns lethal-first and spills the rest.
	var pack := _pack(1)
	advance_to_next_turn()
	var bears := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	wurm.added_keywords.append(Mtg.Keyword.TRAMPLE)
	g.recalculate()
	run_combat([wurm.id], {pack[0].id: wurm.id, bears.id: wurm.id})
	assert_eq(g.players[0].life, 17, "1 + 2 lethal, 3 tramples over")
	assert_eq(pack[0].zone, Mtg.Zone.EXILE, "a dead token ceases to exist (CR 704.5e)")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
