extends CardScript
## Song of Serenity — {1}{G} — Enchantment (uncommon, exo).
## Oracle: Creatures that are enchanted can't attack or block.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Song of Serenity", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures that are enchanted can't attack or block.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
