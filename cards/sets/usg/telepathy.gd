extends CardScript
## Telepathy — {U} — Enchantment (uncommon, usg).
## Oracle: Your opponents play with their hands revealed.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Telepathy", "{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Your opponents play with their hands revealed.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
