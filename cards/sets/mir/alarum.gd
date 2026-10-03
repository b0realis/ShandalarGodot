extends CardScript
## Alarum — {1}{W} — Instant (common, mir).
## Oracle: Untap target nonattacking creature. It gets +1/+3 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Alarum", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Untap target nonattacking creature. It gets +1/+3 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
