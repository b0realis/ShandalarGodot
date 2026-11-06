extends CardScript
## Storage Matrix — {3} — Artifact (rare, uds).
## Oracle: As long as this artifact is untapped, each player chooses artifact, creature, or land during their untap step. That player can untap only permanents of the chosen type this step.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Storage Matrix", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("As long as this artifact is untapped, each player chooses artifact, creature, or land during their untap step. That player can untap only permanents of the chosen type this step.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
