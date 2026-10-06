extends CardScript
## Oath of Ghouls — {1}{B} — Enchantment (rare, exo).
## Oracle: At the beginning of each player's upkeep, that player chooses target player whose graveyard has fewer creature cards in it than their graveyard does and is their opponent. The first player may return a creature card from their graveyard to their hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Oath of Ghouls", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each player's upkeep, that player chooses target player whose graveyard has fewer creature cards in it than their graveyard does and is their opponent. The first player may return a creature card from their graveyard to their hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
