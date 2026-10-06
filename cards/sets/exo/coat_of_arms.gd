extends CardScript
## Coat of Arms — {5} — Artifact (rare, exo).
## Oracle: Each creature gets +1/+1 for each other creature on the battlefield that shares at least one creature type with it. (For example, if two Goblin Warriors and a Goblin Shaman are on the battlefield, each gets +2/+2.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Coat of Arms", "{5}", Mtg.CardType.ARTIFACT)
	c.oracle("Each creature gets +1/+1 for each other creature on the battlefield that shares at least one creature type with it. (For example, if two Goblin Warriors and a Goblin Shaman are on the battlefield, each gets +2/+2.)")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
