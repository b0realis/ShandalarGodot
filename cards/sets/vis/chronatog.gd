extends CardScript
## Chronatog — {1}{U} — Creature — Atog (rare, vis).
## Oracle: {0}: This creature gets +3/+3 until end of turn. You skip your next turn. Activate only once each turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Chronatog", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["atog"])
	c.oracle("{0}: This creature gets +3/+3 until end of turn. You skip your next turn. Activate only once each turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
