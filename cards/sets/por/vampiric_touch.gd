extends CardScript
## Vampiric Touch — {2}{B} — Sorcery (Portal, 1997).
## Oracle: Vampiric Touch deals 2 damage to target opponent or planeswalker and you gain 2 life.

func build() -> CardData:
	var c := CardData.new("Vampiric Touch", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Vampiric Touch deals 2 damage to target opponent or planeswalker and you gain 2 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
