extends CardScript
## Lava Hounds — {2}{R}{R} — Creature — Dog (uncommon, wth).
## Oracle: Haste
##         When this creature enters, it deals 4 damage to you.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lava Hounds", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["dog"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste\nWhen this creature enters, it deals 4 damage to you.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
