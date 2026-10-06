extends CardScript
## Spike Cannibal — {1}{B}{B} — Creature — Spike (uncommon, exo).
## Oracle: This creature enters with a +1/+1 counter on it.
##         When this creature enters, move all +1/+1 counters from all creatures onto it.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spike Cannibal", "{1}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["spike"])
	c.oracle("This creature enters with a +1/+1 counter on it.\nWhen this creature enters, move all +1/+1 counters from all creatures onto it.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
