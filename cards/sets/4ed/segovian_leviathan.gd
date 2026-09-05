extends CardScript
## Segovian Leviathan — {4}{U} — Creature — Leviathan — 3/3 (4ed, uncommon; first printed in Legends)
## Oracle: Islandwalk
##
## Implementation: pure islandwalk on an efficient blue body — the second
## Legends graduation, and blue's answer to Bog Wraith against any deck
## running Islands (duals included, by subtype).


func build() -> CardData:
	return CardData.new("Segovian Leviathan", "{4}{U}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["leviathan"]) \
		.with_landwalk(["island"]) \
		.oracle("Islandwalk")
