extends CardScript
## Cloud Djinn — {5}{U} — Creature — Djinn (uncommon, wth).
## Oracle: Flying
##         This creature can block only creatures with flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cloud Djinn", "{5}{U}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["djinn"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nThis creature can block only creatures with flying.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
