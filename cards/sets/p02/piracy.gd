extends CardScript
## Piracy — {U}{U} — Sorcery (Portal Second Age, 1998).
## Oracle: Until end of turn, you may tap lands you don't control for mana. Spend this mana only to cast spells.

func build() -> CardData:
	var c := CardData.new("Piracy", "{U}{U}", Mtg.CardType.SORCERY)
	c.oracle("Until end of turn, you may tap lands you don't control for mana. Spend this mana only to cast spells.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
