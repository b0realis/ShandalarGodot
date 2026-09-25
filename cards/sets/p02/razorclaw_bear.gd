extends CardScript
## Razorclaw Bear — {2}{G}{G} — Creature — Bear — 3/3 (Portal Second Age, 1998).
## Oracle: Whenever this creature becomes blocked, it gets +2/+2 until end of turn.

func build() -> CardData:
	var c := CardData.new("Razorclaw Bear", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["bear"])
	c.oracle("Whenever this creature becomes blocked, it gets +2/+2 until end of turn.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
