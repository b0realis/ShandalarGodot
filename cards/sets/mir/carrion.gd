extends CardScript
## Carrion — {1}{B}{B} — Instant (rare, mir).
## Oracle: As an additional cost to cast this spell, sacrifice a creature.
##         Create X 0/1 black Insect creature tokens, where X is the sacrificed creature's power.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Carrion", "{1}{B}{B}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, sacrifice a creature.\nCreate X 0/1 black Insect creature tokens, where X is the sacrificed creature's power.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
