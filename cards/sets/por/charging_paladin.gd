extends CardScript
## Charging Paladin — {2}{W} — Creature — Human Knight (Portal, 1997).
## Oracle: Whenever this creature attacks, it gets +0/+3 until end of turn.

func build() -> CardData:
	var c := CardData.new("Charging Paladin", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human", "knight"])
	c.oracle("Whenever this creature attacks, it gets +0/+3 until end of turn.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
