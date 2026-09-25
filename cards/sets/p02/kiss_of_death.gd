extends CardScript
## Kiss of Death — {4}{B}{B} — Sorcery (Portal Second Age, 1998).
## Oracle: Kiss of Death deals 4 damage to target opponent or planeswalker. You gain 4 life.

func build() -> CardData:
	var c := CardData.new("Kiss of Death", "{4}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Kiss of Death deals 4 damage to target opponent or planeswalker. You gain 4 life.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
