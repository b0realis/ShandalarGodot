extends CardScript
## Capashen Templar — {2}{W} — Creature — Human Knight (common, uds).
## Oracle: {W}: This creature gets +0/+1 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Capashen Templar", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.oracle("{W}: This creature gets +0/+1 until end of turn.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
