extends CardScript
## Brushwagg — {1}{G}{G} — Creature — Brushwagg (rare, mir).
## Oracle: Whenever this creature blocks or becomes blocked, it gets -2/+2 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Brushwagg", "{1}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["brushwagg"])
	c.oracle("Whenever this creature blocks or becomes blocked, it gets -2/+2 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
