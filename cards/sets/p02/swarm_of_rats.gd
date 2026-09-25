extends CardScript
## Swarm of Rats — {1}{B} — Creature — Rat — */1 (Portal Second Age, 1998).
## Oracle: Swarm of Rats's power is equal to the number of Rats you control.

func build() -> CardData:
	var c := CardData.new("Swarm of Rats", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 1)
	c.with_subtypes(["rat"])
	c.oracle("Swarm of Rats's power is equal to the number of Rats you control.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
