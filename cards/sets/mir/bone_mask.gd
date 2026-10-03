extends CardScript
## Bone Mask — {4} — Artifact (rare, mir).
## Oracle: {2}, {T}: The next time a source of your choice would deal damage to you this turn, prevent that damage. Exile cards from the top of your library equal to the damage prevented this way.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bone Mask", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}, {T}: The next time a source of your choice would deal damage to you this turn, prevent that damage. Exile cards from the top of your library equal to the damage prevented this way.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
