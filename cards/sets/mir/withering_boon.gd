extends CardScript
## Withering Boon — {1}{B} — Instant (uncommon, mir).
## Oracle: As an additional cost to cast this spell, pay 3 life.
##         Counter target creature spell.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Withering Boon", "{1}{B}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, pay 3 life.\nCounter target creature spell.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
