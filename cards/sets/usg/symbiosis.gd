extends CardScript
## Symbiosis — {1}{G} — Instant (common, usg).
## Oracle: Two target creatures each get +2/+2 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Symbiosis", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Two target creatures each get +2/+2 until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
