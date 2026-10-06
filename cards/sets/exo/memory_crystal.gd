extends CardScript
## Memory Crystal — {3} — Artifact (rare, exo).
## Oracle: Buyback costs cost {2} less.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Memory Crystal", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("Buyback costs cost {2} less.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
