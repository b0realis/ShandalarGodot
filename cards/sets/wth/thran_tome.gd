extends CardScript
## Thran Tome — {4} — Artifact — Book (rare, wth).
## Oracle: {5}, {T}: Reveal the top three cards of your library. Target opponent chooses one of those cards. Put that card into your graveyard, then draw two cards.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thran Tome", "{4}", Mtg.CardType.ARTIFACT)
	c.with_subtypes(["book"])
	c.oracle("{5}, {T}: Reveal the top three cards of your library. Target opponent chooses one of those cards. Put that card into your graveyard, then draw two cards.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
