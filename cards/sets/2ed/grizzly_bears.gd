extends CardScript
## Grizzly Bears — {1}{G} — Creature — Bear — 2/2 (Alpha, common)
## Oracle: (no rules text — vanilla creature)
##
## Implementation: pure stats. This file doubles as the minimal example of
## a creature card; see docs/adding-cards.md, which walks through it.


func build() -> CardData:
	return CardData.new("Grizzly Bears", "{1}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["bear"]) \
		.oracle("")
