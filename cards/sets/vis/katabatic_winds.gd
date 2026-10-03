extends CardScript
## Katabatic Winds — {2}{G} — Enchantment (rare, vis).
## Oracle: Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)
##         Creatures with flying can't attack or block, and their activated abilities with {T} in their costs can't be activated.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Katabatic Winds", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)\nCreatures with flying can't attack or block, and their activated abilities with {T} in their costs can't be activated.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
