extends CardScript
## Endless Wurm — {3}{G}{G} — Creature — Wurm (rare, usg).
## Oracle: Trample
##         At the beginning of your upkeep, sacrifice this creature unless you sacrifice an enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Endless Wurm", "{3}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(9, 9)
	c.with_subtypes(["wurm"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\nAt the beginning of your upkeep, sacrifice this creature unless you sacrifice an enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
