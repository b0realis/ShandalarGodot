extends CardScript
## Defender of Law — {2}{W} — Creature — Human Knight (common, ulg).
## Oracle: Flash
##         Protection from red
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Defender of Law", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["human","knight"])
	c.with_keywords([Mtg.Keyword.FLASH])
	c.with_protection_from(Mtg.ManaColor.R)
	c.oracle("Flash\nProtection from red")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
