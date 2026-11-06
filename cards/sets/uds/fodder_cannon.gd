extends CardScript
## Fodder Cannon — {4} — Artifact (uncommon, uds).
## Oracle: {4}, {T}, Sacrifice a creature: This artifact deals 4 damage to target creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fodder Cannon", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{4}, {T}, Sacrifice a creature: This artifact deals 4 damage to target creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
