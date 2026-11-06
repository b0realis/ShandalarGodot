extends CardScript
## Treacherous Link — {1}{B} — Enchantment — Aura (uncommon, ulg).
## Oracle: Enchant creature
##         All damage that would be dealt to enchanted creature is dealt to its controller instead.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Treacherous Link", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nAll damage that would be dealt to enchanted creature is dealt to its controller instead.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
