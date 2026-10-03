extends CardScript
## Amulet of Unmaking — {5} — Artifact (rare, mir).
## Oracle: {5}, {T}, Exile this artifact: Exile target artifact, creature, or land. Activate only as a sorcery.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Amulet of Unmaking", "{5}", Mtg.CardType.ARTIFACT)
	c.oracle("{5}, {T}, Exile this artifact: Exile target artifact, creature, or land. Activate only as a sorcery.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
