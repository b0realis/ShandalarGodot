extends CardScript
## Kukemssa Serpent — {3}{U} — Creature — Serpent (common, mir).
## Oracle: This creature can't attack unless defending player controls an Island.
##         {U}, Sacrifice an Island: Target land an opponent controls becomes an Island until end of turn.
##         When you control no Islands, sacrifice this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kukemssa Serpent", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["serpent"])
	c.oracle("This creature can't attack unless defending player controls an Island.\n{U}, Sacrifice an Island: Target land an opponent controls becomes an Island until end of turn.\nWhen you control no Islands, sacrifice this creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
