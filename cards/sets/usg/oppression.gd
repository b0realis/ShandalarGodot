extends CardScript
## Oppression — {1}{B}{B} — Enchantment (rare, usg).
## Oracle: Whenever a player casts a spell, that player discards a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Oppression", "{1}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a player casts a spell, that player discards a card.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
