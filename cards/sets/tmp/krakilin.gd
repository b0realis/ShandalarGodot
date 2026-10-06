extends CardScript
## Krakilin — {X}{G}{G} — Creature — Beast (uncommon, tmp).
## Oracle: This creature enters with X +1/+1 counters on it.
##         {1}{G}: Regenerate this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Krakilin", "{X}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["beast"])
	c.oracle("This creature enters with X +1/+1 counters on it.\n{1}{G}: Regenerate this creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
