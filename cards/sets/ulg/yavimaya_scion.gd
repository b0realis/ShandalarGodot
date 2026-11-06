extends CardScript
## Yavimaya Scion — {4}{G} — Creature — Treefolk (common, ulg).
## Oracle: Protection from artifacts
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Yavimaya Scion", "{4}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["treefolk"])
	c.oracle("Protection from artifacts")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
