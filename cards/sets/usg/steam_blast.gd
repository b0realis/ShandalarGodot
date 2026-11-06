extends CardScript
## Steam Blast — {2}{R} — Sorcery (uncommon, usg).
## Oracle: Steam Blast deals 2 damage to each creature and each player.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Steam Blast", "{2}{R}", Mtg.CardType.SORCERY)
	c.oracle("Steam Blast deals 2 damage to each creature and each player.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
