extends CardScript
## Helm of Awakening — {2} — Artifact (uncommon, vis).
## Oracle: Spells cost {1} less to cast.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Helm of Awakening", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("Spells cost {1} less to cast.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
