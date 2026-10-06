extends CardScript
## Spike Rogue — {1}{G}{G} — Creature — Spike (uncommon, exo).
## Oracle: This creature enters with two +1/+1 counters on it.
##         {2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.
##         {2}, Remove a +1/+1 counter from a creature you control: Put a +1/+1 counter on this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spike Rogue", "{1}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["spike"])
	c.oracle("This creature enters with two +1/+1 counters on it.\n{2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.\n{2}, Remove a +1/+1 counter from a creature you control: Put a +1/+1 counter on this creature.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
