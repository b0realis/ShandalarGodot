extends CardScript
## Spike Drone — {G} — Creature — Spike Drone (common, tmp).
## Oracle: This creature enters with a +1/+1 counter on it.
##         {2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spike Drone", "{G}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["spike","drone"])
	c.oracle("This creature enters with a +1/+1 counter on it.\n{2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
