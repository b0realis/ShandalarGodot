extends CardScript
## Spike Weaver — {2}{G}{G} — Creature — Spike (rare, exo).
## Oracle: This creature enters with three +1/+1 counters on it.
##         {2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.
##         {1}, Remove a +1/+1 counter from this creature: Prevent all combat damage that would be dealt this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spike Weaver", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["spike"])
	c.oracle("This creature enters with three +1/+1 counters on it.\n{2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.\n{1}, Remove a +1/+1 counter from this creature: Prevent all combat damage that would be dealt this turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
