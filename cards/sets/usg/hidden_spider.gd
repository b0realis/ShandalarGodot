extends CardScript
## Hidden Spider — {G} — Enchantment (common, usg).
## Oracle: When an opponent casts a creature spell with flying, if this permanent is an enchantment, it becomes a 3/5 Spider creature with reach. (It can block creatures with flying.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hidden Spider", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent casts a creature spell with flying, if this permanent is an enchantment, it becomes a 3/5 Spider creature with reach. (It can block creatures with flying.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
