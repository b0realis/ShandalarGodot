extends CardScript
## Mistmoon Griffin — {3}{W} — Creature — Griffin (uncommon, wth).
## Oracle: Flying
##         When this creature dies, exile it, then return the top creature card of your graveyard to the battlefield.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mistmoon Griffin", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["griffin"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature dies, exile it, then return the top creature card of your graveyard to the battlefield.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
