extends CardScript
## Chaotic Goo — {2}{R}{R} — Creature — Ooze (rare, tmp).
## Oracle: This creature enters with three +1/+1 counters on it.
##         At the beginning of your upkeep, you may flip a coin. If you win the flip, put a +1/+1 counter on this creature. If you lose the flip, remove a +1/+1 counter from this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Chaotic Goo", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["ooze"])
	c.oracle("This creature enters with three +1/+1 counters on it.\nAt the beginning of your upkeep, you may flip a coin. If you win the flip, put a +1/+1 counter on this creature. If you lose the flip, remove a +1/+1 counter from this creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
