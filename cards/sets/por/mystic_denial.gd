extends CardScript
## Mystic Denial — {1}{U}{U} — Instant (Portal, 1997).
## Oracle: Counter target creature or sorcery spell.

func build() -> CardData:
	var c := CardData.new("Mystic Denial", "{1}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target creature or sorcery spell.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
