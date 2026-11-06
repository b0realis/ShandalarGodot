extends CardScript
## Crosswinds — {1}{G} — Enchantment (uncommon, usg).
## Oracle: Creatures with flying get -2/-0.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crosswinds", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures with flying get -2/-0.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
