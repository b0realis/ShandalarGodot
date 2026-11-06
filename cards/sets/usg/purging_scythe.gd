extends CardScript
## Purging Scythe — {5} — Artifact (rare, usg).
## Oracle: At the beginning of your upkeep, this artifact deals 2 damage to the creature with the least toughness. If two or more creatures are tied for least toughness, you choose one of them.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Purging Scythe", "{5}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of your upkeep, this artifact deals 2 damage to the creature with the least toughness. If two or more creatures are tied for least toughness, you choose one of them.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
