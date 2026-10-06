extends CardScript
## Tortured Existence — {B} — Enchantment (common, sth).
## Oracle: {B}, Discard a creature card: Return target creature card from your graveyard to your hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tortured Existence", "{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{B}, Discard a creature card: Return target creature card from your graveyard to your hand.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
