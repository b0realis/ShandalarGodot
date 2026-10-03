extends CardScript
## Zirilan of the Claw — {3}{R}{R} — Legendary Creature — Lizard Shaman (rare, mir).
## Oracle: {1}{R}{R}, {T}: Search your library for a Dragon permanent card, put that card onto the battlefield, then shuffle. That Dragon gains haste until end of turn. Exile it at the beginning of the next end step.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Zirilan of the Claw", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["lizard","shaman"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{1}{R}{R}, {T}: Search your library for a Dragon permanent card, put that card onto the battlefield, then shuffle. That Dragon gains haste until end of turn. Exile it at the beginning of the next end step.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
