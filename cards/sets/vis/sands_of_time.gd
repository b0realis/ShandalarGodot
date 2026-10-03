extends CardScript
## Sands of Time — {4} — Artifact (rare, vis).
## Oracle: Each player skips their untap step.
##         At the beginning of each player's upkeep, that player simultaneously untaps each tapped artifact, creature, and land they control and taps each untapped artifact, creature, and land they control.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sands of Time", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("Each player skips their untap step.\nAt the beginning of each player's upkeep, that player simultaneously untaps each tapped artifact, creature, and land they control and taps each untapped artifact, creature, and land they control.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
