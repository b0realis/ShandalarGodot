extends CardScript
## Vernal Bloom — {3}{G} — Enchantment (rare, usg).
## Oracle: Whenever a Forest is tapped for mana, its controller adds an additional {G}.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vernal Bloom", "{3}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a Forest is tapped for mana, its controller adds an additional {G}.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
