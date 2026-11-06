extends CardScript
## Thieving Magpie — {2}{U}{U} — Creature — Bird (uncommon, uds).
## Oracle: Flying (This creature can't be blocked except by creatures with flying or reach.)
##         Whenever this creature deals damage to an opponent, draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thieving Magpie", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying (This creature can't be blocked except by creatures with flying or reach.)\nWhenever this creature deals damage to an opponent, draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
