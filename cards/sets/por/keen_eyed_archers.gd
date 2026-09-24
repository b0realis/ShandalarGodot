extends CardScript
## Keen-Eyed Archers — {2}{W} — Creature — Elf Archer (Portal, 1997).
## Oracle: Reach (This creature can block creatures with flying.)

func build() -> CardData:
	var c := CardData.new("Keen-Eyed Archers", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["elf", "archer"])
	c.with_keywords([Mtg.Keyword.REACH])
	c.oracle("Reach (This creature can block creatures with flying.)")
	return c
