extends CardScript
## Molten Hydra — {1}{R} — Creature — Hydra (rare, ulg).
## Oracle: {1}{R}{R}: Put a +1/+1 counter on this creature.
##         {T}, Remove all +1/+1 counters from this creature: It deals damage to any target equal to the number of +1/+1 counters removed this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Molten Hydra", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["hydra"])
	c.oracle("{1}{R}{R}: Put a +1/+1 counter on this creature.\n{T}, Remove all +1/+1 counters from this creature: It deals damage to any target equal to the number of +1/+1 counters removed this way.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
