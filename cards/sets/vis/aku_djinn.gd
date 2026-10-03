extends CardScript
## Aku Djinn — {3}{B}{B} — Creature — Djinn (rare, vis).
## Oracle: Trample
##         At the beginning of your upkeep, put a +1/+1 counter on each creature each opponent controls.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Aku Djinn", "{3}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(5, 6)
	c.with_subtypes(["djinn"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\nAt the beginning of your upkeep, put a +1/+1 counter on each creature each opponent controls.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
