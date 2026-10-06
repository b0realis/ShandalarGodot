extends CardScript
## Spike Soldier — {2}{G}{G} — Creature — Spike Soldier (uncommon, sth).
## Oracle: This creature enters with three +1/+1 counters on it.
##         {2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.
##         Remove a +1/+1 counter from this creature: This creature gets +2/+2 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spike Soldier", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["spike","soldier"])
	c.oracle("This creature enters with three +1/+1 counters on it.\n{2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.\nRemove a +1/+1 counter from this creature: This creature gets +2/+2 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
