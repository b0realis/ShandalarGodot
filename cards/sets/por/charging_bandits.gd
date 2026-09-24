extends CardScript
## Charging Bandits — {4}{B} — Creature — Human Rogue (Portal, 1997).
## Oracle: Whenever this creature attacks, it gets +2/+0 until end of turn.

func build() -> CardData:
	var c := CardData.new("Charging Bandits", "{4}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["human", "rogue"])
	c.oracle("Whenever this creature attacks, it gets +2/+0 until end of turn.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
