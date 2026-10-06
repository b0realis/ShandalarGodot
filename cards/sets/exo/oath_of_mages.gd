extends CardScript
## Oath of Mages — {1}{R} — Enchantment (rare, exo).
## Oracle: At the beginning of each player's upkeep, that player chooses target player who has more life than they do and is their opponent. The first player may have this enchantment deal 1 damage to the second player.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Oath of Mages", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each player's upkeep, that player chooses target player who has more life than they do and is their opponent. The first player may have this enchantment deal 1 damage to the second player.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
