extends CardScript
## Exalted Dragon — {4}{W}{W} — Creature — Dragon (rare, exo).
## Oracle: Flying
##         This creature can't attack unless you sacrifice a land. (This cost is paid as attackers are declared.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Exalted Dragon", "{4}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nThis creature can't attack unless you sacrifice a land. (This cost is paid as attackers are declared.)")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
