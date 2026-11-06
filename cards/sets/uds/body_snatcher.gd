extends CardScript
## Body Snatcher — {2}{B}{B} — Creature — Phyrexian Minion (rare, uds).
## Oracle: When this creature enters, exile it unless you discard a creature card.
##         When this creature dies, exile it and return target creature card from your graveyard to the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Body Snatcher", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["phyrexian","minion"])
	c.oracle("When this creature enters, exile it unless you discard a creature card.\nWhen this creature dies, exile it and return target creature card from your graveyard to the battlefield.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
