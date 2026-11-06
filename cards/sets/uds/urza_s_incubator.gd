extends CardScript
## Urza's Incubator — {3} — Artifact (rare, uds).
## Oracle: As this artifact enters, choose a creature type.
##         Creature spells of the chosen type cost {2} less to cast.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Urza's Incubator", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("As this artifact enters, choose a creature type.\nCreature spells of the chosen type cost {2} less to cast.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
