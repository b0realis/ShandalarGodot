extends CardScript
## Skeletal Snake — {1}{B} — Creature — Snake Skeleton (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Skeletal Snake", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["snake", "skeleton"])
	c.oracle("")
	return c
