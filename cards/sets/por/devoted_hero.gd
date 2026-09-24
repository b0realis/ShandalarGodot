extends CardScript
## Devoted Hero — {W} — Creature — Elf Soldier (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Devoted Hero", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["elf", "soldier"])
	c.oracle("")
	return c
