extends CardScript
## Rainbow Efreet — {3}{U} — Creature — Efreet (rare, vis).
## Oracle: Flying
##         {U}{U}: This creature phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before you untap during your next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rainbow Efreet", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 1)
	c.with_subtypes(["efreet"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{U}{U}: This creature phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before you untap during your next untap step.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
