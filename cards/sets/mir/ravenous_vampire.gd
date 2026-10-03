extends CardScript
## Ravenous Vampire — {3}{B}{B} — Creature — Vampire (uncommon, mir).
## Oracle: Flying
##         At the beginning of your upkeep, you may sacrifice a nonartifact creature. If you do, put a +1/+1 counter on this creature. If you don't, tap this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ravenous Vampire", "{3}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["vampire"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nAt the beginning of your upkeep, you may sacrifice a nonartifact creature. If you do, put a +1/+1 counter on this creature. If you don't, tap this creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
