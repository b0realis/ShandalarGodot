extends CardScript
## Caltrops — {3} — Artifact (uncommon, uds).
## Oracle: Whenever a creature attacks, this artifact deals 1 damage to it.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Caltrops", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("Whenever a creature attacks, this artifact deals 1 damage to it.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
