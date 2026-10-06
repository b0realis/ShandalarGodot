extends CardScript
## Manakin — {2} — Artifact Creature — Construct (common, tmp).
## Oracle: {T}: Add {C}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Manakin", "{2}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(1, 1)
	c.with_subtypes(["construct"])
	c.oracle("{T}: Add {C}.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
