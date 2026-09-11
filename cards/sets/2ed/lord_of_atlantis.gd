extends CardScript
## Lord of Atlantis — {U}{U} — Creature — Merfolk — 2/2 (2ed, rare)
## Oracle: Other Merfolk get +1/+1 and have islandwalk.
##
## Implementation: the TRIBAL LORD pattern — a global static boosting every
## OTHER merfolk (both players'! — modern oracle and the original agree)
## and granting islandwalk via the LIVE cur_landwalk list, which combat
## legality reads. Note "other": the lord excludes itself (two lords pump
## each other, classically).


func build() -> CardData:
	return CardData.new("Lord of Atlantis", "{U}{U}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["merfolk"]) \
		.static_ability(StaticAbility.new(
			_apply, "Other Merfolk get +1/+1.")) \
		.static_ability(StaticAbility.new(
			_walk, "Other Merfolk have islandwalk.").changing_abilities()) \
		.oracle("Other Merfolk get +1/+1 and have islandwalk.")


## TWO STATICS, one per CR 613 layer (613.1): the +1/+1 is layer 7c and
## the islandwalk is layer 6, where it is timestamped against Hammerheim's
## "loses all landwalk abilities".
static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst != source and inst.is_creature() and inst.has_subtype("merfolk"):
			inst.cur_power += 1
			inst.cur_toughness += 1


static func _walk(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst != source and inst.is_creature() and inst.has_subtype("merfolk") \
				and not inst.cur_landwalk.has("island"):
			inst.cur_landwalk.append("island")
