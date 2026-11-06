extends CardScript
## Back to Basics — {2}{U} — Enchantment (rare, usg).
## Oracle: Nonbasic lands don't untap during their controllers' untap steps.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Back to Basics", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Nonbasic lands don't untap during their controllers' untap steps.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
