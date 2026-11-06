extends CardScript
## Voice of Reason — {3}{W} — Creature — Angel (uncommon, uds).
## Oracle: Flying, protection from blue
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Voice of Reason", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["angel"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.with_protection_from(Mtg.ManaColor.U)
	c.oracle("Flying, protection from blue")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
