extends CardScript
## Blood Frenzy — {1}{R} — Instant (common, tmp).
## Oracle: Cast this spell only before the combat damage step.
##         Target attacking or blocking creature gets +4/+0 until end of turn. Destroy that creature at the beginning of the next end step.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Blood Frenzy", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only before the combat damage step.\nTarget attacking or blocking creature gets +4/+0 until end of turn. Destroy that creature at the beginning of the next end step.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
