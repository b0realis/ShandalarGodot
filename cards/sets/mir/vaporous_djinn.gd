extends CardScript
## Vaporous Djinn — {2}{U}{U} — Creature — Djinn (uncommon, mir).
## Oracle: Flying
##         At the beginning of your upkeep, this creature phases out unless you pay {U}{U}. (While it's phased out, it's treated as though it doesn't exist. It phases in before you untap during your next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vaporous Djinn", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["djinn"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nAt the beginning of your upkeep, this creature phases out unless you pay {U}{U}. (While it's phased out, it's treated as though it doesn't exist. It phases in before you untap during your next untap step.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
