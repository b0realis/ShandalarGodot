extends CardScript
## Canyon Drake — {2}{R}{R} — Creature — Drake (rare, tmp).
## Oracle: Flying
##         {1}, Discard a card at random: This creature gets +2/+0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Canyon Drake", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{1}, Discard a card at random: This creature gets +2/+0 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
