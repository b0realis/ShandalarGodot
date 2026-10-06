extends CardScript
## Souldrinker — {3}{B} — Creature — Spirit (uncommon, tmp).
## Oracle: Pay 3 life: Put a +1/+1 counter on this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Souldrinker", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["spirit"])
	c.oracle("Pay 3 life: Put a +1/+1 counter on this creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
