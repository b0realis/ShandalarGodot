extends CardScript
## Academy Rector — {3}{W} — Creature — Human Cleric (rare, uds).
## Oracle: When this creature dies, you may exile it. If you do, search your library for an enchantment card, put that card onto the battlefield, then shuffle.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Academy Rector", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","cleric"])
	c.oracle("When this creature dies, you may exile it. If you do, search your library for an enchantment card, put that card onto the battlefield, then shuffle.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
