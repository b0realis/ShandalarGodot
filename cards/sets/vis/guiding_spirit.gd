extends CardScript
## Guiding Spirit — {1}{W}{U} — Creature — Angel Spirit (rare, vis).
## Oracle: Flying
##         {T}: If the top card of target player's graveyard is a creature card, put that card on top of that player's library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Guiding Spirit", "{1}{W}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["angel","spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{T}: If the top card of target player's graveyard is a creature card, put that card on top of that player's library.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
