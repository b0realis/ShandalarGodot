extends CardScript
## Resistance Fighter — {W} — Creature — Human Soldier (common, vis).
## Oracle: Sacrifice this creature: Prevent all combat damage target creature would deal this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Resistance Fighter", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","soldier"])
	c.oracle("Sacrifice this creature: Prevent all combat damage target creature would deal this turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
