extends CardScript
## Benalish Knight — {2}{W} — Creature — Human Knight (common, wth).
## Oracle: Flash (You may cast this spell any time you could cast an instant.)
##         First strike (This creature deals combat damage before creatures without first strike.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Benalish Knight", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("Flash (You may cast this spell any time you could cast an instant.)\nFirst strike (This creature deals combat damage before creatures without first strike.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
