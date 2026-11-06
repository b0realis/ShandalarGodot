extends CardScript
## Fluctuator — {2} — Artifact (rare, usg).
## Oracle: Cycling abilities you activate cost {2} less to activate.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fluctuator", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("Cycling abilities you activate cost {2} less to activate.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
