extends CardScript
## Skyshroud Troopers — {3}{G} — Creature — Elf Druid Warrior (common, sth).
## Oracle: {T}: Add {G}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skyshroud Troopers", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["elf","druid","warrior"])
	c.oracle("{T}: Add {G}.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
