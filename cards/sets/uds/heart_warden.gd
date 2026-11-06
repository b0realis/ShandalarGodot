extends CardScript
## Heart Warden — {1}{G} — Creature — Elf Druid (common, uds).
## Oracle: {T}: Add {G}.
##         {2}, Sacrifice this creature: Draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Heart Warden", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf","druid"])
	c.oracle("{T}: Add {G}.\n{2}, Sacrifice this creature: Draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
