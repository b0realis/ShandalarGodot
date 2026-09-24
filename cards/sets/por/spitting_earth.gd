extends CardScript
## Spitting Earth — {1}{R} — Sorcery (Portal, 1997).
## Oracle: Spitting Earth deals damage to target creature equal to the number of Mountains you control.

func build() -> CardData:
	var c := CardData.new("Spitting Earth", "{1}{R}", Mtg.CardType.SORCERY)
	c.oracle("Spitting Earth deals damage to target creature equal to the number of Mountains you control.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
