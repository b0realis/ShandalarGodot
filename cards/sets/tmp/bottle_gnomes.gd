extends CardScript
## Bottle Gnomes — {3} — Artifact Creature — Gnome (uncommon, tmp).
## Oracle: Sacrifice this creature: You gain 3 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bottle Gnomes", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(1, 3)
	c.with_subtypes(["gnome"])
	c.oracle("Sacrifice this creature: You gain 3 life.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
