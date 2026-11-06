extends CardScript
## Witch Engine — {5}{B} — Creature — Horror (rare, usg).
## Oracle: Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)
##         {T}: Add {B}{B}{B}{B}. Target opponent gains control of this creature. (Activate only as an instant.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Witch Engine", "{5}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["horror"])
	c.with_landwalk(["swamp"])
	c.oracle("Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)\n{T}: Add {B}{B}{B}{B}. Target opponent gains control of this creature. (Activate only as an instant.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
