extends CardScript
## Teferi's Curse — {1}{U} — Enchantment — Aura (common, mir).
## Oracle: Enchant artifact or creature
##         Enchanted permanent has phasing. (It phases in or out before its controller untaps during each of their untap steps. While it's phased out, it's treated as though it doesn't exist.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Teferi's Curse", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant artifact or creature\nEnchanted permanent has phasing. (It phases in or out before its controller untaps during each of their untap steps. While it's phased out, it's treated as though it doesn't exist.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
