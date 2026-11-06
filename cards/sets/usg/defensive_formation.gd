extends CardScript
## Defensive Formation — {W} — Enchantment (uncommon, usg).
## Oracle: Rather than the attacking player, you assign the combat damage of each creature attacking you. You can divide that creature's combat damage as you choose among any of the creatures blocking it.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Defensive Formation", "{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Rather than the attacking player, you assign the combat damage of each creature attacking you. You can divide that creature's combat damage as you choose among any of the creatures blocking it.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
