extends CardScript
## Thrull Surgeon — {1}{B} — Creature — Thrull (common, exo).
## Oracle: {1}{B}, Sacrifice this creature: Look at target player's hand and choose a card from it. That player discards that card. Activate only as a sorcery.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thrull Surgeon", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["thrull"])
	c.oracle("{1}{B}, Sacrifice this creature: Look at target player's hand and choose a card from it. That player discards that card. Activate only as a sorcery.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
