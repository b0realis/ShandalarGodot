extends CardScript
## Absolute Law — {1}{W} — Enchantment (uncommon, usg).
## Oracle: All creatures have protection from red.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Absolute Law", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("All creatures have protection from red.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
