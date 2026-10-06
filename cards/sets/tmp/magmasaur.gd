extends CardScript
## Magmasaur — {3}{R}{R} — Creature — Elemental Dinosaur (rare, tmp).
## Oracle: This creature enters with five +1/+1 counters on it.
##         At the beginning of your upkeep, you may remove a +1/+1 counter from this creature. If you don't, sacrifice this creature and it deals damage equal to the number of +1/+1 counters on it to each creature without flying and each player.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Magmasaur", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["elemental","dinosaur"])
	c.oracle("This creature enters with five +1/+1 counters on it.\nAt the beginning of your upkeep, you may remove a +1/+1 counter from this creature. If you don't, sacrifice this creature and it deals damage equal to the number of +1/+1 counters on it to each creature without flying and each player.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
