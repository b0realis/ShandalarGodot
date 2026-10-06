extends CardScript
## Watchdog — {3} — Artifact Creature — Dog (uncommon, tmp).
## Oracle: This creature blocks each combat if able.
##         As long as this creature is untapped, all creatures attacking you get -1/-0.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Watchdog", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(1, 2)
	c.with_subtypes(["dog"])
	c.oracle("This creature blocks each combat if able.\nAs long as this creature is untapped, all creatures attacking you get -1/-0.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
