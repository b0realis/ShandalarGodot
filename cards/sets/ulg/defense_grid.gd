extends CardScript
## Defense Grid — {2} — Artifact (rare, ulg).
## Oracle: Each spell costs {3} more to cast except during its controller's turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Defense Grid", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("Each spell costs {3} more to cast except during its controller's turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
