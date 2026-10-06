extends CardScript
## Sphere of Resistance — {2} — Artifact (rare, exo).
## Oracle: Spells cost {1} more to cast.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sphere of Resistance", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("Spells cost {1} more to cast.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
