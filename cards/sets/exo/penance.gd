extends CardScript
## Penance — {2}{W} — Enchantment (uncommon, exo).
## Oracle: Put a card from your hand on top of your library: The next time a black or red source of your choice would deal damage this turn, prevent that damage.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Penance", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Put a card from your hand on top of your library: The next time a black or red source of your choice would deal damage this turn, prevent that damage.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
