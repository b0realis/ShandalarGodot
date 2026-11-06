extends CardScript
## Capashen Knight — {1}{W} — Creature — Human Knight (common, uds).
## Oracle: First strike (This creature deals combat damage before creatures without first strike.)
##         {1}{W}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Capashen Knight", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","knight"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike (This creature deals combat damage before creatures without first strike.)\n{1}{W}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
