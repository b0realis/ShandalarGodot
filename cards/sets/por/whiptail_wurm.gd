extends CardScript
## Whiptail Wurm — {6}{G} — Creature — Wurm (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Whiptail Wurm", "{6}{G}", Mtg.CardType.CREATURE)
	c.pt(8, 5)
	c.with_subtypes(["wurm"])
	c.oracle("")
	return c
