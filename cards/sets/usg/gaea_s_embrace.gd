extends CardScript
## Gaea's Embrace — {2}{G}{G} — Enchantment — Aura (uncommon, usg).
## Oracle: Enchant creature
##         Enchanted creature gets +3/+3 and has trample.
##         {G}: Regenerate enchanted creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gaea's Embrace", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +3/+3 and has trample.\n{G}: Regenerate enchanted creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
