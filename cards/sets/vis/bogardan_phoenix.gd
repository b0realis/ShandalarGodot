extends CardScript
## Bogardan Phoenix — {2}{R}{R}{R} — Creature — Phoenix (rare, vis).
## Oracle: Flying
##         When this creature dies, exile it if it had a death counter on it. Otherwise, return it to the battlefield under your control and put a death counter on it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bogardan Phoenix", "{2}{R}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["phoenix"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature dies, exile it if it had a death counter on it. Otherwise, return it to the battlefield under your control and put a death counter on it.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
