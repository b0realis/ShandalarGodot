extends CardScript
## Southern Paladin — {2}{W}{W} — Creature — Human Knight (rare, wth).
## Oracle: {W}{W}, {T}: Destroy target red permanent.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Southern Paladin", "{2}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["human","knight"])
	c.oracle("{W}{W}, {T}: Destroy target red permanent.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
