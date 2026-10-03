extends CardScript
## Xanthic Statue — {8} — Artifact (rare, wth).
## Oracle: {5}: Until end of turn, this artifact becomes an 8/8 Golem artifact creature with trample.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Xanthic Statue", "{8}", Mtg.CardType.ARTIFACT)
	c.oracle("{5}: Until end of turn, this artifact becomes an 8/8 Golem artifact creature with trample.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
