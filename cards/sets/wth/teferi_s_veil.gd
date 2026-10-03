extends CardScript
## Teferi's Veil — {1}{U} — Enchantment (uncommon, wth).
## Oracle: Whenever a creature you control attacks, it phases out at end of combat. (While it's phased out, it's treated as though it doesn't exist. It phases in before you untap during your next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Teferi's Veil", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature you control attacks, it phases out at end of combat. (While it's phased out, it's treated as though it doesn't exist. It phases in before you untap during your next untap step.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
