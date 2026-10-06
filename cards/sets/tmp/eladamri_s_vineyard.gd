extends CardScript
## Eladamri's Vineyard — {G} — Enchantment (rare, tmp).
## Oracle: At the beginning of each player's first main phase, that player adds {G}{G}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Eladamri's Vineyard", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each player's first main phase, that player adds {G}{G}.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
