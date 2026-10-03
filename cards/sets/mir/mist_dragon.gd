extends CardScript
## Mist Dragon — {4}{U}{U} — Creature — Dragon (rare, mir).
## Oracle: {0}: This creature gains flying. (This effect lasts indefinitely.)
##         {0}: This creature loses flying. (This effect lasts indefinitely.)
##         {3}{U}{U}: This creature phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before you untap during your next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mist Dragon", "{4}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["dragon"])
	c.oracle("{0}: This creature gains flying. (This effect lasts indefinitely.)\n{0}: This creature loses flying. (This effect lasts indefinitely.)\n{3}{U}{U}: This creature phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before you untap during your next untap step.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
