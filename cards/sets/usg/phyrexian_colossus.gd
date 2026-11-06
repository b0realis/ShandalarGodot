extends CardScript
## Phyrexian Colossus — {7} — Artifact Creature — Phyrexian Golem (rare, usg).
## Oracle: This creature doesn't untap during your untap step.
##         Pay 8 life: Untap this creature.
##         This creature can't be blocked except by three or more creatures.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Colossus", "{7}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(8, 8)
	c.with_subtypes(["phyrexian","golem"])
	c.oracle("This creature doesn't untap during your untap step.\nPay 8 life: Untap this creature.\nThis creature can't be blocked except by three or more creatures.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
