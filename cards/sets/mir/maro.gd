extends CardScript
## Maro — {2}{G}{G} — Creature — Elemental (rare, mir).
## Oracle: Maro's power and toughness are each equal to the number of cards in your hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Maro", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["elemental"])
	c.oracle("Maro's power and toughness are each equal to the number of cards in your hand.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
