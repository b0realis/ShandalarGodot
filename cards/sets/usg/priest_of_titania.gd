extends CardScript
## Priest of Titania — {1}{G} — Creature — Elf Druid (common, usg).
## Oracle: {T}: Add {G} for each Elf on the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Priest of Titania", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf","druid"])
	c.oracle("{T}: Add {G} for each Elf on the battlefield.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
