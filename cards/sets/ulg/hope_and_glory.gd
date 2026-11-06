extends CardScript
## Hope and Glory — {1}{W} — Instant (uncommon, ulg).
## Oracle: Untap two target creatures. Each of them gets +1/+1 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hope and Glory", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Untap two target creatures. Each of them gets +1/+1 until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
