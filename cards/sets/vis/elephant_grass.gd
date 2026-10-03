extends CardScript
## Elephant Grass — {G} — Enchantment (uncommon, vis).
## Oracle: Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
##         Black creatures can't attack you.
##         Nonblack creatures can't attack you unless their controller pays {2} for each creature they control that's attacking you.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elephant Grass", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)\nBlack creatures can't attack you.\nNonblack creatures can't attack you unless their controller pays {2} for each creature they control that's attacking you.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
