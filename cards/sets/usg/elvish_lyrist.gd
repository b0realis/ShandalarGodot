extends CardScript
## Elvish Lyrist — {G} — Creature — Elf (common, usg).
## Oracle: {G}, {T}, Sacrifice this creature: Destroy target enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elvish Lyrist", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf"])
	c.oracle("{G}, {T}, Sacrifice this creature: Destroy target enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
