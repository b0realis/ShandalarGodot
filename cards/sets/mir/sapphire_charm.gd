extends CardScript
## Sapphire Charm — {U} — Instant (common, mir).
## Oracle: Choose one —
##         • Target player draws a card at the beginning of the next turn's upkeep.
##         • Target creature gains flying until end of turn.
##         • Target creature an opponent controls phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before its controller untaps during their next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sapphire Charm", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Choose one —\n• Target player draws a card at the beginning of the next turn's upkeep.\n• Target creature gains flying until end of turn.\n• Target creature an opponent controls phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before its controller untaps during their next untap step.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
