extends CardScript
## Greener Pastures — {2}{G} — Enchantment (rare, usg).
## Oracle: At the beginning of each player's upkeep, if that player controls more lands than each other player, the player creates a 1/1 green Saproling creature token.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Greener Pastures", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each player's upkeep, if that player controls more lands than each other player, the player creates a 1/1 green Saproling creature token.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
