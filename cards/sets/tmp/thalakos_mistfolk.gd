extends CardScript
## Thalakos Mistfolk — {2}{U} — Creature — Thalakos Illusion (common, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         {U}: Put this creature on top of its owner's library.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thalakos Mistfolk", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["thalakos","illusion"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\n{U}: Put this creature on top of its owner's library.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
