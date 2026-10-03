extends CardScript
## Acidic Dagger — {4} — Artifact (rare, mir).
## Oracle: {4}, {T}: Whenever target creature deals combat damage to a non-Wall creature this turn, destroy that non-Wall creature. When the targeted creature leaves the battlefield this turn, sacrifice this artifact. Activate only before blockers are declared.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Acidic Dagger", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{4}, {T}: Whenever target creature deals combat damage to a non-Wall creature this turn, destroy that non-Wall creature. When the targeted creature leaves the battlefield this turn, sacrifice this artifact. Activate only before blockers are declared.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
