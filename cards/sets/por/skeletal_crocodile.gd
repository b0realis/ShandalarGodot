extends CardScript
## Skeletal Crocodile — {3}{B} — Creature — Crocodile Skeleton (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Skeletal Crocodile", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(5, 1)
	c.with_subtypes(["crocodile", "skeleton"])
	c.oracle("")
	return c
