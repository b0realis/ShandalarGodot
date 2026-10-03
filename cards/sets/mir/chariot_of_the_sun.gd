extends CardScript
## Chariot of the Sun — {3} — Artifact (uncommon, mir).
## Oracle: {2}, {T}: Until end of turn, target creature you control gains flying and has base toughness 1.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Chariot of the Sun", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}, {T}: Until end of turn, target creature you control gains flying and has base toughness 1.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
