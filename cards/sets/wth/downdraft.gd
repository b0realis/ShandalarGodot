extends CardScript
## Downdraft — {2}{G} — Enchantment (uncommon, wth).
## Oracle: {G}: Target creature loses flying until end of turn.
##         Sacrifice this enchantment: It deals 2 damage to each creature with flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Downdraft", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{G}: Target creature loses flying until end of turn.\nSacrifice this enchantment: It deals 2 damage to each creature with flying.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
