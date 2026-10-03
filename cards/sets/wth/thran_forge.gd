extends CardScript
## Thran Forge — {3} — Artifact (uncommon, wth).
## Oracle: {2}: Until end of turn, target nonartifact creature gets +1/+0 and becomes an artifact in addition to its other types.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thran Forge", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}: Until end of turn, target nonartifact creature gets +1/+0 and becomes an artifact in addition to its other types.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
