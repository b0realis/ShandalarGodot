extends CardScript
## Serra Advocate — {3}{W} — Creature — Angel (uncommon, uds).
## Oracle: Flying
##         {T}: Target attacking or blocking creature gets +2/+2 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Serra Advocate", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["angel"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{T}: Target attacking or blocking creature gets +2/+2 until end of turn.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
