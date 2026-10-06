extends CardScript
## Skyshaper — {2} — Artifact (uncommon, exo).
## Oracle: Sacrifice this artifact: Creatures you control gain flying until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skyshaper", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("Sacrifice this artifact: Creatures you control gain flying until end of turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
