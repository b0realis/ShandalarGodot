extends CardScript
## Goblin Lore — {1}{R} — Sorcery (Portal Second Age, 1998).
## Oracle: Draw four cards, then discard three cards at random.

func build() -> CardData:
	var c := CardData.new("Goblin Lore", "{1}{R}", Mtg.CardType.SORCERY)
	c.oracle("Draw four cards, then discard three cards at random.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
