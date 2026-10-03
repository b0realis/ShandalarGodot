extends CardScript
## Choking Vines — {X}{G} — Instant (common, wth).
## Oracle: Cast this spell only during the declare blockers step.
##         X target attacking creatures become blocked. Choking Vines deals 1 damage to each of those creatures. (This spell works on creatures that can't be blocked.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Choking Vines", "{X}{G}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare blockers step.\nX target attacking creatures become blocked. Choking Vines deals 1 damage to each of those creatures. (This spell works on creatures that can't be blocked.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
