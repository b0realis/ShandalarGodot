extends CardScript
## Thopter Squadron — {5} — Artifact Creature — Thopter (rare, exo).
## Oracle: Flying
##         This creature enters with three +1/+1 counters on it.
##         {1}, Remove a +1/+1 counter from this creature: Create a 1/1 colorless Thopter artifact creature token with flying. Activate only as a sorcery.
##         {1}, Sacrifice another Thopter: Put a +1/+1 counter on this creature. Activate only as a sorcery.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thopter Squadron", "{5}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(0, 0)
	c.with_subtypes(["thopter"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nThis creature enters with three +1/+1 counters on it.\n{1}, Remove a +1/+1 counter from this creature: Create a 1/1 colorless Thopter artifact creature token with flying. Activate only as a sorcery.\n{1}, Sacrifice another Thopter: Put a +1/+1 counter on this creature. Activate only as a sorcery.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
