extends CardScript
## Phyrexian Vault — {3} — Artifact (uncommon, mir).
## Oracle: {2}, {T}, Sacrifice a creature: Draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Vault", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}, {T}, Sacrifice a creature: Draw a card.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
