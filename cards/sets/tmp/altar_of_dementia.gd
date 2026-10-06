extends CardScript
## Altar of Dementia — {2} — Artifact (rare, tmp).
## Oracle: Sacrifice a creature: Target player mills cards equal to the sacrificed creature's power.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Altar of Dementia", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("Sacrifice a creature: Target player mills cards equal to the sacrificed creature's power.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
