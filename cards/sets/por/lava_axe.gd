extends CardScript
## Lava Axe — {4}{R} — Sorcery (Portal, 1997).
## Oracle: Lava Axe deals 5 damage to target player or planeswalker.

func build() -> CardData:
	var c := CardData.new("Lava Axe", "{4}{R}", Mtg.CardType.SORCERY)
	c.oracle("Lava Axe deals 5 damage to target player or planeswalker.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
