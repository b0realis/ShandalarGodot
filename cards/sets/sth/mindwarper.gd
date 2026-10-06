extends CardScript
## Mindwarper — {2}{B}{B} — Creature — Spirit (rare, sth).
## Oracle: This creature enters with three +1/+1 counters on it.
##         {2}{B}, Remove a +1/+1 counter from this creature: Target player discards a card. Activate only as a sorcery.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mindwarper", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["spirit"])
	c.oracle("This creature enters with three +1/+1 counters on it.\n{2}{B}, Remove a +1/+1 counter from this creature: Target player discards a card. Activate only as a sorcery.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
