extends CardScript
## Heat Wave — {2}{R} — Enchantment (uncommon, vis).
## Oracle: Cumulative upkeep {R} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
##         Blue creatures can't block creatures you control.
##         Nonblue creatures can't block creatures you control unless their controller pays 1 life for each blocking creature they control.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Heat Wave", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Cumulative upkeep {R} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)\nBlue creatures can't block creatures you control.\nNonblue creatures can't block creatures you control unless their controller pays 1 life for each blocking creature they control.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
