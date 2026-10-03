extends CardScript
## Vision Charm — {U} — Instant (common, vis).
## Oracle: Choose one —
##         • Target player mills four cards.
##         • Choose a land type and a basic land type. Each land of the first chosen type becomes the second chosen type until end of turn.
##         • Target artifact phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before its controller untaps during their next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vision Charm", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Choose one —\n• Target player mills four cards.\n• Choose a land type and a basic land type. Each land of the first chosen type becomes the second chosen type until end of turn.\n• Target artifact phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before its controller untaps during their next untap step.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
