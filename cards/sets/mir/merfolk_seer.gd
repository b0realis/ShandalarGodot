extends CardScript
## Merfolk Seer — {2}{U} — Creature — Merfolk Wizard (common, mir).
## Oracle: When this creature dies, you may pay {1}{U}. If you do, draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Merfolk Seer", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["merfolk","wizard"])
	c.oracle("When this creature dies, you may pay {1}{U}. If you do, draw a card.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
