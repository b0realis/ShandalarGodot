extends CardScript
## Null Chamber — {3}{W} — World Enchantment (rare, mir).
## Oracle: As this enchantment enters, you and an opponent each choose a card name other than a basic land card name.
##         Spells with the chosen names can't be cast and lands with the chosen names can't be played.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Null Chamber", "{3}{W}", Mtg.CardType.ENCHANTMENT)
	c.supertypes |= Mtg.Supertype.WORLD
	c.oracle("As this enchantment enters, you and an opponent each choose a card name other than a basic land card name.\nSpells with the chosen names can't be cast and lands with the chosen names can't be played.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
