extends CardScript
## Spike Feeder — {1}{G}{G} — Creature — Spike (uncommon, sth).
## Oracle: This creature enters with two +1/+1 counters on it.
##         {2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.
##         Remove a +1/+1 counter from this creature: You gain 2 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spike Feeder", "{1}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["spike"])
	c.oracle("This creature enters with two +1/+1 counters on it.\n{2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.\nRemove a +1/+1 counter from this creature: You gain 2 life.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
