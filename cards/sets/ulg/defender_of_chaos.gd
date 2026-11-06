extends CardScript
## Defender of Chaos — {2}{R} — Creature — Human Knight (common, ulg).
## Oracle: Flash
##         Protection from white
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Defender of Chaos", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["human","knight"])
	c.with_keywords([Mtg.Keyword.FLASH])
	c.with_protection_from(Mtg.ManaColor.W)
	c.oracle("Flash\nProtection from white")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
