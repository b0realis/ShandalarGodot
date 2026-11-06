extends CardScript
## Anthroplasm — {2}{U}{U} — Creature — Shapeshifter (rare, ulg).
## Oracle: This creature enters with two +1/+1 counters on it.
##         {X}, {T}: Remove all +1/+1 counters from this creature and put X +1/+1 counters on it.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Anthroplasm", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["shapeshifter"])
	c.oracle("This creature enters with two +1/+1 counters on it.\n{X}, {T}: Remove all +1/+1 counters from this creature and put X +1/+1 counters on it.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
