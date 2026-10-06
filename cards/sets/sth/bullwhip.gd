extends CardScript
## Bullwhip — {4} — Artifact (uncommon, sth).
## Oracle: {2}, {T}: This artifact deals 1 damage to target creature. That creature attacks this turn if able.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bullwhip", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}, {T}: This artifact deals 1 damage to target creature. That creature attacks this turn if able.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
