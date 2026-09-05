extends CardScript
## Timber Wolves — {G} — Creature — Wolf — 1/1 (2ed, rare)
## Oracle: Banding (Any creatures with banding, and up to one without, can
##         attack in a band. Bands are blocked as a group.)
##
## Implementation: BANDING keyword — green's copy of Benalish Hero.
## Rules in combat.gd.


func build() -> CardData:
	return CardData.new("Timber Wolves", "{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["wolf"]) \
		.with_keywords([Mtg.Keyword.BANDING]) \
		.oracle("Banding")
