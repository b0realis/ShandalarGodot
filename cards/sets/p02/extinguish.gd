extends CardScript
## Extinguish — {1}{U} — Instant (Portal Second Age, 1998).
## Oracle: Counter target sorcery spell.

func build() -> CardData:
	var c := CardData.new("Extinguish", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target sorcery spell.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
