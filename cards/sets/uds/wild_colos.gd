extends CardScript
## Wild Colos — {2}{R} — Creature — Goat Beast (common, uds).
## Oracle: Haste
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wild Colos", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["goat","beast"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
