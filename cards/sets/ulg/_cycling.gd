extends RefCounted
## Urza's Legacy (_cycling, Pack 10). Cycling cards and "when you cycle" cards.
##
## CYCLING (CR 702.29a) is [method CardData.with_cycling] (Pack 10 engine
## package E2), appended after each card's own text — see
## cards/sets/usg/_cycling.gd for the mechanism. The rest is the pool's own
## shapes:
##
## - Iron Will: a +0/+4 pump. Radiant's Judgment / Swat: destroy a creature
##   judged by its LIVE power, as cast and again as it resolves (a pumped
##   target can slip out of Swat's range, CR 608.2b).
## - Cloud of Faeries: flying (the scaffold's) and "When this creature
##   enters, untap up to two lands" — [UntapUpToEffect] from
##   cards/sets/usg/_untap.gd (B9): chosen as it resolves, either player's
##   tapped lands, up to two.
## - Miscalculation: Mana Leak's toll counter for {2} (F.TollCounter).
## - Rebuild: every artifact (live types: an artifact creature, an animated
##   artifact) leaves together (MtgGame.depart_together, Evacuation's shape)
##   to its owner's hand.
## - Unearth: a creature card with mana value 3 or less (X counts as 0 in
##   the graveyard, CR 202.3e) from YOUR graveyard to the battlefield under
##   your control (MtgGame.reanimate: the normal entering path).
## - Repopulate: every creature card in the target player's graveyard goes
##   into that player's library, which is then shuffled (Barishi's shape).
## - Bloated Toad / Darkwatch Elves: protection (the scaffold's) and cycling.
##
## tests/cards/test_pack_10_B11_cycling.gd (every card's cycling) and
## test_pack_10_B11_ulg_uds.gd (each card's own text) pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const U := preload("res://cards/sets/usg/_untap.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Iron Will":
			c.spell(PumpEffect.new(0, 4))
		"Radiant's Judgment":
			c.spell(DestroyEffect.new(TargetSpec.creature(
				"target creature with power 4 or greater", _power_four_or_more)))
		"Cloud of Faeries":
			c.triggered(U.enters_untapping(2, "When this creature enters, untap up to two lands."))
		"Miscalculation":
			c.spell(F.TollCounter.new("{2}"))
		"Rebuild":
			c.spell(F.Action.new(_rebuild, "return all artifacts to their owners' hands") \
				.with_ai_role(&"mass_artifact_bounce"))
		"Swat":
			c.spell(DestroyEffect.new(TargetSpec.creature(
				"target creature with power 2 or less", _power_two_or_less)))
		"Unearth":
			var unearth := ReturnFromGraveyardEffect.new().to_battlefield()
			unearth.target_spec = TargetSpec.new(TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD,
				"target creature card with mana value 3 or less from your graveyard", _mana_value_three_or_less)
			c.spell(unearth)
		"Bloated Toad", "Darkwatch Elves":
			pass   # protection: the scaffold's
		"Repopulate":
			c.spell(F.Action.new(_repopulate,
				"shuffle all creature cards from target player's graveyard into that player's library",
				TargetSpec.player()).with_ai_role(&"graveyard_creatures_to_library"))
		_: return false
	c.with_cycling()
	return true


static func _power_four_or_more(i: CardInstance) -> bool: return i.cur_power >= 4
static func _power_two_or_less(i: CardInstance) -> bool: return i.cur_power <= 2
static func _mana_value_three_or_less(i: CardInstance) -> bool:
	return i.data.cost.mana_value() <= 3


## Every artifact at once (one bracket, CR 704.3), by live types.
static func _rebuild(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var leaving: Array[CardInstance] = []
	for i in g.all_battlefield():
		if i.is_type(Mtg.CardType.ARTIFACT) and g.is_present(i): leaving.append(i)
	if leaving.is_empty(): return
	g.depart_together(leaving, g.return_to_hand)


static func _repopulate(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if t == null or not t.is_player:
		return
	var who := t.player_id
	for card in g.players[who].graveyard.duplicate():
		if card.is_creature(): g.return_from_graveyard_to_library_top(card)
	g.shuffle_library(who)
