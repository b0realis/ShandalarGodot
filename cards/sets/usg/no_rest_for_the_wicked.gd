extends CardScript
## No Rest for the Wicked — {1}{B} — Enchantment (uncommon, usg).
## Oracle: Sacrifice this enchantment: Return to your hand all creature cards in your graveyard that were put there from the battlefield this turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("No Rest for the Wicked", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Sacrifice this enchantment: Return to your hand all creature cards in your graveyard that were put there from the battlefield this turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
