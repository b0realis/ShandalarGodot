extends CardScript
## Arcane Laboratory — {2}{U} — Enchantment (uncommon, usg).
## Oracle: Each player can't cast more than one spell each turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Arcane Laboratory", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Each player can't cast more than one spell each turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
