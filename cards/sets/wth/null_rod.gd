extends CardScript
## Null Rod — {2} — Artifact (rare, wth).
## Oracle: Activated abilities of artifacts can't be activated.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Null Rod", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("Activated abilities of artifacts can't be activated.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
