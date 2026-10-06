extends CardScript
## Thalakos Seer — {U}{U} — Creature — Thalakos Wizard (common, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         When this creature leaves the battlefield, draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thalakos Seer", "{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["thalakos","wizard"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nWhen this creature leaves the battlefield, draw a card.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
