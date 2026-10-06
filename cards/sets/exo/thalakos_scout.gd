extends CardScript
## Thalakos Scout — {2}{U} — Creature — Thalakos Soldier Scout (common, exo).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         Discard a card: Return this creature to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thalakos Scout", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["thalakos","soldier","scout"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nDiscard a card: Return this creature to its owner's hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
