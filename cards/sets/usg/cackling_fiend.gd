extends CardScript
## Cackling Fiend — {2}{B}{B} — Creature — Zombie (common, usg).
## Oracle: When this creature enters, each opponent discards a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cackling Fiend", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["zombie"])
	c.oracle("When this creature enters, each opponent discards a card.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
