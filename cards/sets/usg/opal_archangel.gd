extends CardScript
## Opal Archangel — {4}{W} — Enchantment (rare, usg).
## Oracle: When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 5/5 Angel creature with flying and vigilance.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Opal Archangel", "{4}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 5/5 Angel creature with flying and vigilance.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
