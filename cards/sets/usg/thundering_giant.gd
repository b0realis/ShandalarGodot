extends CardScript
## Thundering Giant — {3}{R}{R} — Creature — Giant (uncommon, usg).
## Oracle: Haste (This creature can attack and {T} as soon as it comes under your control.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thundering Giant", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["giant"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste (This creature can attack and {T} as soon as it comes under your control.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
