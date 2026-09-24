extends CardScript
## Taunt — {U} — Sorcery (Portal, 1997).
## Oracle: During target player's next turn, creatures that player controls attack you if able.

func build() -> CardData:
	var c := CardData.new("Taunt", "{U}", Mtg.CardType.SORCERY)
	c.oracle("During target player's next turn, creatures that player controls attack you if able.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
