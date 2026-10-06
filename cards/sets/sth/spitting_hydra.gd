extends CardScript
## Spitting Hydra — {3}{R}{R} — Creature — Hydra (rare, sth).
## Oracle: This creature enters with four +1/+1 counters on it.
##         {1}{R}, Remove a +1/+1 counter from this creature: It deals 1 damage to target creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spitting Hydra", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["hydra"])
	c.oracle("This creature enters with four +1/+1 counters on it.\n{1}{R}, Remove a +1/+1 counter from this creature: It deals 1 damage to target creature.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
