extends CardScript
## Crystal Chimes — {3} — Artifact (uncommon, usg).
## Oracle: {3}, {T}, Sacrifice this artifact: Return all enchantment cards from your graveyard to your hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crystal Chimes", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}, {T}, Sacrifice this artifact: Return all enchantment cards from your graveyard to your hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
