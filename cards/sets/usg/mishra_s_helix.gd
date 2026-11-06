extends CardScript
## Mishra's Helix — {5} — Artifact (rare, usg).
## Oracle: {X}, {T}: Tap X target lands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mishra's Helix", "{5}", Mtg.CardType.ARTIFACT)
	c.oracle("{X}, {T}: Tap X target lands.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
