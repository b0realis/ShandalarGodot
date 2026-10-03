extends CardScript
## Alms — {W} — Enchantment (common, wth).
## Oracle: {1}, Exile the top card of your graveyard: Prevent the next 1 damage that would be dealt to target creature this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Alms", "{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{1}, Exile the top card of your graveyard: Prevent the next 1 damage that would be dealt to target creature this turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
