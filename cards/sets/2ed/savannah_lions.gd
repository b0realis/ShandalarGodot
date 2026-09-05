extends CardScript
## Savannah Lions — {W} — Creature — Cat — 2/1 (Alpha, rare)
## Oracle: (no rules text — vanilla creature)
##
## Implementation: pure stats. Historically the benchmark aggressive
## one-drop of the Shandalar-era card pool (see dos486 guide notes in
## ../../docs at the repo root).


func build() -> CardData:
	return CardData.new("Savannah Lions", "{W}", Mtg.CardType.CREATURE) \
		.pt(2, 1) \
		.with_subtypes(["cat"]) \
		.oracle("")
