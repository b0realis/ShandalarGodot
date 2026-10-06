extends CardScript
## Emerald Medallion — {2} — Artifact (rare, tmp).
## Oracle: Green spells you cast cost {1} less to cast.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Emerald Medallion", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("Green spells you cast cost {1} less to cast.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
