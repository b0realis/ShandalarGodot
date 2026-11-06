extends CardScript
## Greater Good — {2}{G}{G} — Enchantment (rare, usg).
## Oracle: Sacrifice a creature: Draw cards equal to the sacrificed creature's power, then discard three cards.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Greater Good", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Sacrifice a creature: Draw cards equal to the sacrificed creature's power, then discard three cards.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
