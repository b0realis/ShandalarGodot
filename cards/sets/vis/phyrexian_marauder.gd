extends CardScript
## Phyrexian Marauder — {X} — Artifact Creature — Phyrexian Construct (rare, vis).
## Oracle: This creature enters with X +1/+1 counters on it.
##         This creature can't block.
##         This creature can't attack unless you pay {1} for each +1/+1 counter on it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Marauder", "{X}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(0, 0)
	c.with_subtypes(["phyrexian","construct"])
	c.oracle("This creature enters with X +1/+1 counters on it.\nThis creature can't block.\nThis creature can't attack unless you pay {1} for each +1/+1 counter on it.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
