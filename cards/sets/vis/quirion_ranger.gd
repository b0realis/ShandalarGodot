extends CardScript
## Quirion Ranger — {G} — Creature — Elf Ranger (common, vis).
## Oracle: Return a Forest you control to its owner's hand: Untap target creature. Activate only once each turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Quirion Ranger", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf","ranger"])
	c.oracle("Return a Forest you control to its owner's hand: Untap target creature. Activate only once each turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
