extends CardScript
## Propaganda — {2}{U} — Enchantment (uncommon, tmp).
## Oracle: Creatures can't attack you unless their controller pays {2} for each creature they control that's attacking you.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Propaganda", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures can't attack you unless their controller pays {2} for each creature they control that's attacking you.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
