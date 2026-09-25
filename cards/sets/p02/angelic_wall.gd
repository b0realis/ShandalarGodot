extends CardScript
## Angelic Wall — {1}{W} — Creature — Wall — 0/4 (Portal Second Age, 1998).
## Oracle: Defender (This creature can't attack.)
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Angelic Wall", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(0, 4)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.DEFENDER])
	c.oracle("Defender (This creature can't attack.)\nFlying")
	return c
