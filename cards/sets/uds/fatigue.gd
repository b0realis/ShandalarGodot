extends CardScript
## Fatigue — {1}{U} — Sorcery (common, uds).
## Oracle: Target player skips their next draw step.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fatigue", "{1}{U}", Mtg.CardType.SORCERY)
	c.oracle("Target player skips their next draw step.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
