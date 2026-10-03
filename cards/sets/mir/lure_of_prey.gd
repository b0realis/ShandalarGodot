extends CardScript
## Lure of Prey — {2}{G}{G} — Instant (rare, mir).
## Oracle: Cast this spell only if an opponent cast a creature spell this turn.
##         You may put a green creature card from your hand onto the battlefield.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lure of Prey", "{2}{G}{G}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only if an opponent cast a creature spell this turn.\nYou may put a green creature card from your hand onto the battlefield.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
