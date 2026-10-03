extends CardScript
## Roc Hatchling — {R} — Creature — Bird (uncommon, wth).
## Oracle: This creature enters with four shell counters on it.
##         At the beginning of your upkeep, remove a shell counter from this creature.
##         As long as this creature has no shell counters on it, it gets +3/+2 and has flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Roc Hatchling", "{R}", Mtg.CardType.CREATURE)
	c.pt(0, 1)
	c.with_subtypes(["bird"])
	c.oracle("This creature enters with four shell counters on it.\nAt the beginning of your upkeep, remove a shell counter from this creature.\nAs long as this creature has no shell counters on it, it gets +3/+2 and has flying.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
