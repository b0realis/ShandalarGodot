extends CardScript
## Seedling Charm — {G} — Instant (common, mir).
## Oracle: Choose one —
##         • Return target Aura attached to a creature to its owner's hand.
##         • Regenerate target green creature.
##         • Target creature gains trample until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Seedling Charm", "{G}", Mtg.CardType.INSTANT)
	c.oracle("Choose one —\n• Return target Aura attached to a creature to its owner's hand.\n• Regenerate target green creature.\n• Target creature gains trample until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
