extends CardScript
## Absolute Grace — {1}{W} — Enchantment (uncommon, usg).
## Oracle: All creatures have protection from black.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Absolute Grace", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("All creatures have protection from black.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
