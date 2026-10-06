extends CardScript
## Erratic Portal — {4} — Artifact (rare, exo).
## Oracle: {1}, {T}: Return target creature to its owner's hand unless its controller pays {1}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Erratic Portal", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{1}, {T}: Return target creature to its owner's hand unless its controller pays {1}.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
