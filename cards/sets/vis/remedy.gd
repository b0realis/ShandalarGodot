extends CardScript
## Remedy — {1}{W} — Instant (common, vis).
## Oracle: Prevent the next 5 damage that would be dealt this turn to any number of targets, divided as you choose.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Remedy", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Prevent the next 5 damage that would be dealt this turn to any number of targets, divided as you choose.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
