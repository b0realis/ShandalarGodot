extends CardScript
## Regal Unicorn — {2}{W} — Creature — Unicorn (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Regal Unicorn", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["unicorn"])
	c.oracle("")
	return c
