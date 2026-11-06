extends CardScript
## Veil of Birds — {U} — Enchantment (common, usg).
## Oracle: When an opponent casts a spell, if this permanent is an enchantment, it becomes a 1/1 Bird creature with flying.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Veil of Birds", "{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent casts a spell, if this permanent is an enchantment, it becomes a 1/1 Bird creature with flying.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
