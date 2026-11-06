extends CardScript
## Pariah — {2}{W} — Enchantment — Aura (rare, usg).
## Oracle: Enchant creature
##         All damage that would be dealt to you is dealt to enchanted creature instead.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pariah", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nAll damage that would be dealt to you is dealt to enchanted creature instead.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
