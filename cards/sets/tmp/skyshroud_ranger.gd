extends CardScript
## Skyshroud Ranger — {G} — Creature — Elf Ranger (common, tmp).
## Oracle: {T}: You may put a land card from your hand onto the battlefield. Activate only as a sorcery.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skyshroud Ranger", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf","ranger"])
	c.oracle("{T}: You may put a land card from your hand onto the battlefield. Activate only as a sorcery.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
