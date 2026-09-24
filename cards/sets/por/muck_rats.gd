extends CardScript
## Muck Rats — {B} — Creature — Rat (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Muck Rats", "{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["rat"])
	c.oracle("")
	return c
