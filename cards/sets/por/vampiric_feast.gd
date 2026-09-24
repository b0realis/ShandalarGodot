extends CardScript
## Vampiric Feast — {5}{B}{B} — Sorcery (Portal, 1997).
## Oracle: Vampiric Feast deals 4 damage to any target and you gain 4 life.

func build() -> CardData:
	var c := CardData.new("Vampiric Feast", "{5}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Vampiric Feast deals 4 damage to any target and you gain 4 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
