extends CardScript
## Volcanic Hammer — {1}{R} — Sorcery (Portal, 1997).
## Oracle: Volcanic Hammer deals 3 damage to any target.

func build() -> CardData:
	var c := CardData.new("Volcanic Hammer", "{1}{R}", Mtg.CardType.SORCERY)
	c.oracle("Volcanic Hammer deals 3 damage to any target.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
