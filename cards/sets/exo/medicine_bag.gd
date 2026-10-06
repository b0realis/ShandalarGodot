extends CardScript
## Medicine Bag — {3} — Artifact (uncommon, exo).
## Oracle: {1}, {T}, Discard a card: Regenerate target creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Medicine Bag", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{1}, {T}, Discard a card: Regenerate target creature.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
