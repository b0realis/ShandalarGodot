extends CardScript
## Spike Hatcher — {6}{G} — Creature — Spike (rare, exo).
## Oracle: This creature enters with six +1/+1 counters on it.
##         {2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.
##         {1}, Remove a +1/+1 counter from this creature: Regenerate this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spike Hatcher", "{6}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["spike"])
	c.oracle("This creature enters with six +1/+1 counters on it.\n{2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.\n{1}, Remove a +1/+1 counter from this creature: Regenerate this creature.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
