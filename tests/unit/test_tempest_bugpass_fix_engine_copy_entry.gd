extends GameTest
## Pack 9 bug pass (fix-engine) — finding h2-7: a permanent entering AS A
## COPY is judged as the copy for every other replacement that modifies how
## it enters (CR 614.12, "taking into account replacement effects that have
## already modified how it enters"). Copy Artifact entering as a copy of
## Mox Diamond has Mox Diamond's "If this artifact would enter, you may
## discard a land card instead. If you do, put this artifact onto the
## battlefield. If you don't, put it into its owner's graveyard."


const PRESETS: Array[String] = ["modern", "fifth"]


## A seat whose card answers are scripted by name (else the first, or none
## with [member decline]), and which remembers every prompt.
class Seat extends DecisionAgent:
	var prefer: Array = []
	var asked: Array = []
	var decline := false

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		if decline and prompt.begins_with("Copy"):
			return null
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


var me: Seat


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	g.set_agent(0, me)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _fresh(preset: String) -> void:
	before_each()
	g.rules.set_edition(preset)


## Mox Diamond onto seat 1's battlefield the honest way (its land card paid).
func _their_mox() -> CardInstance:
	give_hand(1, "Island")
	var mox := put_battlefield(1, "Mox Diamond")
	assert_eq(mox.zone, Mtg.Zone.BATTLEFIELD, "setup: their Mox paid its land card")
	return mox


func _cast_copy_artifact() -> CardInstance:
	var copy := give_hand(0, "Copy Artifact")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, copy))
	resolve_stack()
	return copy


func test_copy_artifact_as_mox_diamond_without_a_land_card_goes_to_the_graveyard() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var their_mox := _their_mox()
		var bear := give_hand(0, "Grizzly Bears")
		me.prefer = ["Mox Diamond"]
		var copy := _cast_copy_artifact()
		assert_true(me.asked.any(func(p: String) -> bool: return p.begins_with("Copy")),
			"%s: the copy question was asked" % preset)
		assert_eq(their_mox.zone, Mtg.Zone.BATTLEFIELD, preset)
		assert_eq(bear.zone, Mtg.Zone.HAND, preset)
		assert_eq(copy.zone, Mtg.Zone.GRAVEYARD,
			"%s: as a Mox Diamond with no land card to discard, it goes to its owner's graveyard" % preset)
		assert_eq(copy.data.card_name, "Copy Artifact",
			"%s: in the graveyard it is its printed self again (CR 707.2)" % preset)
		assert_false(g.players[0].battlefield.has(copy), preset)


func test_copy_artifact_as_mox_diamond_discards_a_land_card() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_their_mox()
		var forest := give_hand(0, "Forest")
		me.prefer = ["Mox Diamond", "Forest"]
		var copy := _cast_copy_artifact()
		assert_eq(copy.zone, Mtg.Zone.BATTLEFIELD, preset)
		assert_eq(copy.data.card_name, "Mox Diamond", preset)
		assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "%s: the Mox copy's land card was discarded" % preset)


## Controls: declining the copy, Copy Artifact enters as printed and pays
## nothing; Mox Diamond's own payment is unchanged.
func test_copy_artifact_declining_the_copy_pays_nothing() -> void:
	_their_mox()
	var forest := give_hand(0, "Forest")
	me.decline = true
	var copy := _cast_copy_artifact()
	assert_eq(copy.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(copy.data.card_name, "Copy Artifact")
	assert_eq(forest.zone, Mtg.Zone.HAND)


func test_mox_diamond_itself_still_asks_for_its_land_card() -> void:
	var mox := give_hand(0, "Mox Diamond")
	var forest := give_hand(0, "Forest")
	me.prefer = ["Forest"]
	assert_ok(g.cast_spell(0, mox))
	resolve_stack()
	assert_eq(mox.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)


func test_mox_diamond_without_a_land_card_still_goes_to_the_graveyard() -> void:
	var mox := give_hand(0, "Mox Diamond")
	assert_ok(g.cast_spell(0, mox))
	resolve_stack()
	assert_eq(mox.zone, Mtg.Zone.GRAVEYARD)


## Copy Artifact copying an ordinary artifact pays nothing and copies.
func test_copy_artifact_copying_a_plain_artifact_is_unchanged() -> void:
	put_battlefield(1, "Triskelion")
	var forest := give_hand(0, "Forest")
	me.prefer = ["Triskelion"]
	var copy := _cast_copy_artifact()
	assert_eq(copy.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(copy.data.card_name, "Triskelion")
	assert_eq(int(copy.counters.get("+1/+1", 0)), 3, "the copied 'enters with counters' applies")
	assert_eq(forest.zone, Mtg.Zone.HAND)
