extends CardScript
## Frenetic Efreet — {1}{U}{R} — Creature — Efreet (rare, mir).
## Oracle: Flying
##         {0}: Flip a coin. If you win the flip, this creature phases out. If you lose the flip, sacrifice this creature. (While it's phased out, it's treated as though it doesn't exist. It phases in before you untap during your next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Frenetic Efreet", "{1}{U}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["efreet"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{0}: Flip a coin. If you win the flip, this creature phases out. If you lose the flip, sacrifice this creature. (While it's phased out, it's treated as though it doesn't exist. It phases in before you untap during your next untap step.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
