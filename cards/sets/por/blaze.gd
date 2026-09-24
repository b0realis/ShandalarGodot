extends CardScript
## Blaze — {X}{R} — Sorcery (Portal, 1997).
## Oracle: Blaze deals X damage to any target.

func build() -> CardData:
	var c := CardData.new("Blaze", "{X}{R}", Mtg.CardType.SORCERY)
	c.oracle("Blaze deals X damage to any target.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
