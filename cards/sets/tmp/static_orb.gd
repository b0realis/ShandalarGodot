extends CardScript
## Static Orb — {3} — Artifact (rare, tmp).
## Oracle: As long as this artifact is untapped, players can't untap more than two permanents during their untap steps.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Static Orb", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("As long as this artifact is untapped, players can't untap more than two permanents during their untap steps.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
