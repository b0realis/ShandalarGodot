extends CardScript
## Oath of Druids — {1}{G} — Enchantment (rare, exo).
## Oracle: At the beginning of each player's upkeep, that player chooses target player who controls more creatures than they do and is their opponent. The first player may reveal cards from the top of their library until they reveal a creature card. If the first player does, that player puts that card onto the battlefield and all other cards revealed this way into their graveyard.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Oath of Druids", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each player's upkeep, that player chooses target player who controls more creatures than they do and is their opponent. The first player may reveal cards from the top of their library until they reveal a creature card. If the first player does, that player puts that card onto the battlefield and all other cards revealed this way into their graveyard.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
