extends CardScript
## Gravedigger — {3}{B} — Creature — Zombie (Portal, 1997).
## Oracle: When this creature enters, you may return target creature card from your graveyard to your hand.

func build() -> CardData:
	var c := CardData.new("Gravedigger", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["zombie"])
	c.oracle("When this creature enters, you may return target creature card from your graveyard to your hand.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
