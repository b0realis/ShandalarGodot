extends CardScript
## Choke — {2}{G} — Enchantment (uncommon, tmp).
## Oracle: Islands don't untap during their controllers' untap steps.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Choke", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Islands don't untap during their controllers' untap steps.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
