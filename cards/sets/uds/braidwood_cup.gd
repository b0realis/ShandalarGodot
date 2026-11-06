extends CardScript
## Braidwood Cup — {3} — Artifact (uncommon, uds).
## Oracle: {T}: You gain 1 life.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Braidwood Cup", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}: You gain 1 life.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
