extends CardScript
## Shanodin Dryads — {G} — Creature — Nymph Dryad — 1/1 — (2ed, common)
## Oracle: Forestwalk (This creature can't be blocked as long as defending
##         player controls a Forest.)
##
## Implementation: one-drop forestwalker — the landwalk engine (LIVE
## cur_landwalk vs the defender's land subtypes) does all the work.


func build() -> CardData:
	return CardData.new("Shanodin Dryads", "{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["nymph", "dryad"]) \
		.with_landwalk(["forest"]) \
		.oracle("Forestwalk")
