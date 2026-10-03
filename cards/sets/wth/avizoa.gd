extends CardScript
## Avizoa — {3}{U} — Creature — Jellyfish (rare, wth).
## Oracle: Flying
##         {0}: This creature gets +2/+2 until end of turn. You skip your next untap step. Activate only once each turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Avizoa", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["jellyfish"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{0}: This creature gets +2/+2 until end of turn. You skip your next untap step. Activate only once each turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
