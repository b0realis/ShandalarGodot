extends CardScript
## Thran Lens — {2} — Artifact (rare, ulg).
## Oracle: All permanents are colorless.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thran Lens", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("All permanents are colorless.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
