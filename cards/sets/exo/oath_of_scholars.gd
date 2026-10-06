extends CardScript
## Oath of Scholars — {3}{U} — Enchantment (rare, exo).
## Oracle: At the beginning of each player's upkeep, that player chooses target player who has more cards in hand than they do and is their opponent. The first player may discard their hand and draw three cards.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Oath of Scholars", "{3}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each player's upkeep, that player chooses target player who has more cards in hand than they do and is their opponent. The first player may discard their hand and draw three cards.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
