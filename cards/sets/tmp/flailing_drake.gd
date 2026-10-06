extends CardScript
## Flailing Drake — {3}{G} — Creature — Drake (uncommon, tmp).
## Oracle: Flying
##         Whenever this creature blocks or becomes blocked by a creature, that creature gets +1/+1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flailing Drake", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhenever this creature blocks or becomes blocked by a creature, that creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
