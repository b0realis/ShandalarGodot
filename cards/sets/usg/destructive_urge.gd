extends CardScript
## Destructive Urge — {1}{R}{R} — Enchantment — Aura (uncommon, usg).
## Oracle: Enchant creature
##         Whenever enchanted creature deals combat damage to a player, that player sacrifices a land of their choice.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Destructive Urge", "{1}{R}{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhenever enchanted creature deals combat damage to a player, that player sacrifices a land of their choice.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
