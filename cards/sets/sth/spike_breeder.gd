extends CardScript
## Spike Breeder — {3}{G} — Creature — Spike (rare, sth).
## Oracle: This creature enters with three +1/+1 counters on it.
##         {2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.
##         {2}, Remove a +1/+1 counter from this creature: Create a 1/1 green Spike creature token.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spike Breeder", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["spike"])
	c.oracle("This creature enters with three +1/+1 counters on it.\n{2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.\n{2}, Remove a +1/+1 counter from this creature: Create a 1/1 green Spike creature token.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
