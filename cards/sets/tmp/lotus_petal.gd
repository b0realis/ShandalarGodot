extends CardScript
## Lotus Petal — {0} — Artifact (common, tmp).
## Oracle: {T}, Sacrifice this artifact: Add one mana of any color.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lotus Petal", "{0}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}, Sacrifice this artifact: Add one mana of any color.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
