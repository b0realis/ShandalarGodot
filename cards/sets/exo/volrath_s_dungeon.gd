extends CardScript
## Volrath's Dungeon — {2}{B}{B} — Enchantment (rare, exo).
## Oracle: Pay 5 life: Destroy this enchantment. Any player may activate this ability but only during their turn.
##         Discard a card: Target player puts a card from their hand on top of their library. Activate only as a sorcery.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Volrath's Dungeon", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Pay 5 life: Destroy this enchantment. Any player may activate this ability but only during their turn.\nDiscard a card: Target player puts a card from their hand on top of their library. Activate only as a sorcery.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
