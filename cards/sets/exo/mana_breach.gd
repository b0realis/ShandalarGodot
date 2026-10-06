extends CardScript
## Mana Breach — {2}{U} — Enchantment (uncommon, exo).
## Oracle: Whenever a player casts a spell, that player returns a land they control to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mana Breach", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a player casts a spell, that player returns a land they control to its owner's hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
