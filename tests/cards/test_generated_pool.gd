extends GameTest
## Sanity + integration tests for the AUTO-GENERATED card pool
## (tools/gen_cards.py output under cards/sets/<set>/).
##
## Two layers of protection:
## 1. Registry-wide invariants — every registered card, whatever its origin,
##    must satisfy basic sanity (parseable cost, sane creature stats). This
##    catches a bad generator run or a typo'd hand-written card at test time
##    instead of mid-duel.
## 2. Spot integration — generated cards are not just data: a few of them
##    are cast and fought through the real engine to prove generated files
##    behave identically to hand-written ones.


## Every optional pack the suite builds metadata-only (run_tests.sh sets
## SHANDALAR_PACK_1..7): enabling them all is one reload of the registry
## through the same path the Card Packs page uses, not seven.
const ALL_PACKS: Array[String] = [CardPacks.ID, FallenEmpiresPack.ID,
	IceAgePack.ID, HomelandsPack.ID, AlliancesPack.ID, PortalPack.ID,
	FifthEditionPack.ID]


func after_each() -> void:
	g = null
	if not Settings.enabled_card_packs().is_empty():
		_enable_packs([])


func _enable_packs(ids: Array[String]) -> void:
	Settings.set_enabled_card_packs(ids)
	CardPacks.rescan()


func test_every_registered_card_is_sane() -> void:
	for card_name in CardRegistry.all_names():
		_assert_card_is_sane(card_name)


## The base pool above is what the registry holds with no pack enabled;
## the seven packs add a thousand identities more, and the gate had never
## run the invariant over them. Wiitigo (Ice Age) is a printed 0/0 whose
## whole body is the six +1/+1 counters it enters with — a shape the
## exemption list did not know, found by an all-packs engine sweep instead
## of by this suite (2026-09-25). Now every pack card answers here.
func test_every_card_of_every_pack_is_sane() -> void:
	var base := CardRegistry.all_names().size()
	_enable_packs(ALL_PACKS)
	for id in ALL_PACKS:
		assert_true(CardPacks.is_enabled(id), id + " is available to the suite")
	var names := CardRegistry.all_names()
	assert_gt(names.size(), base, "the packs add cards to the pool")
	assert_true(names.has("Wiitigo"), "Ice Age is in the pool")
	for card_name in names:
		_assert_card_is_sane(card_name)


func _assert_card_is_sane(card_name: String) -> void:
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	assert_eq(data.card_name, card_name, "registry key matches card name")
	if data.is_creature():
		if not _derives_its_body(data):
			assert_gt(data.toughness, 0,
				"%s: creatures need toughness >= 1" % card_name)
		assert_gte(data.power, 0, card_name)
	if not data.is_land():
		# mana_value can legitimately be 0 (Ornithopter, the Kobolds),
		# but the cost STRING must exist — an empty one is a parse bug.
		assert_ne(data.cost.text, "",
			"%s: non-land with no cost text is a parse/generation bug" % card_name)
	assert_ne(data.set_code, "", card_name)


## A printed 0/0 is legitimate when the body arrives from somewhere else
## before any state-based action looks at it: a characteristic-defining
## static (Nightmare's */*, Rock Hydra's heads), a copy effect (Clone,
## Vesuvan Doppelganger — they adopt a real body as they enter), or the
## +1/+1 counters it enters with (Wiitigo's six: the one creature across
## the seven packs whose only body is its counters).
static func _derives_its_body(data: CardData) -> bool:
	return not data.static_abilities.is_empty() \
		or not data.enters_as_copy.is_empty() \
		or int(data.enters_with_counters.get("+1/+1", 0)) > 0


func test_generated_keywords_registered() -> void:
	# One generated card per keyword the generator can emit.
	assert_true(CardRegistry.get_card("Mahamoti Djinn").has_keyword(Mtg.Keyword.FLYING))
	assert_true(CardRegistry.get_card("Giant Spider").has_keyword(Mtg.Keyword.REACH))
	assert_true(CardRegistry.get_card("Wall of Stone").has_keyword(Mtg.Keyword.DEFENDER))


func test_generated_vanilla_fights_like_hand_written() -> void:
	# Hill Giant (generated 3/3) trades with Gray Ogre (generated 2/2)?
	# No — it survives: 2 damage vs 3 toughness. Full combat through the
	# real engine using only generated cards.
	var giant := put_battlefield(0, "Hill Giant")
	var ogre := put_battlefield(1, "Gray Ogre")
	run_combat([giant.id], {ogre.id: giant.id})
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD, "3 power kills the 2/2")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "2 damage vs 3 toughness")
	assert_eq(giant.damage, 2)


func test_generated_reach_blocks_flyer() -> void:
	# Giant Spider's reach (generated) blocking Mahamoti Djinn (generated).
	var djinn := put_battlefield(0, "Mahamoti Djinn")   # 5/6 flying
	var spider := put_battlefield(1, "Giant Spider")     # 2/4 reach
	run_combat([djinn.id], {spider.id: djinn.id})
	assert_eq(spider.zone, Mtg.Zone.GRAVEYARD, "5 damage kills the 2/4")
	assert_eq(djinn.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20, "blocked: no player damage")


func test_generated_card_castable() -> void:
	var wurm := give_hand(0, "Craw Wurm")   # {4}{G}{G} 6/4, generated
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, wurm, []))
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.cur_power, 6)
