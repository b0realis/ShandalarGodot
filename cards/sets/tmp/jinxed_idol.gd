extends CardScript
## Jinxed Idol — {2} — Artifact (rare, tmp).
## Oracle: At the beginning of your upkeep, this artifact deals 2 damage to you.
##         Sacrifice a creature: Target opponent gains control of this artifact.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jinxed Idol", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of your upkeep, this artifact deals 2 damage to you.\nSacrifice a creature: Target opponent gains control of this artifact.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
