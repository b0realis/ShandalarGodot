extends CardScript
## Talas Merchant — {1}{U} — Creature — Human Pirate — 1/3 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Talas Merchant", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["human","pirate"])
	c.oracle("")
	return c
