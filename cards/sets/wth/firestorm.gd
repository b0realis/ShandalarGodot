extends CardScript
## Firestorm — {R} — Instant (rare, wth).
## Oracle: As an additional cost to cast this spell, discard X cards.
##         Firestorm deals X damage to each of X targets.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Firestorm", "{R}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, discard X cards.\nFirestorm deals X damage to each of X targets.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
