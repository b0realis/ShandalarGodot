extends CardScript
## Uktabi Orangutan — {2}{G} — Creature — Ape (uncommon, vis).
## Oracle: When this creature enters, destroy target artifact.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Uktabi Orangutan", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["ape"])
	c.oracle("When this creature enters, destroy target artifact.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
