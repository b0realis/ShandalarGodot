extends CardScript
## Abduction — {2}{U}{U} — Enchantment — Aura (uncommon, wth).
## Oracle: Enchant creature
##         When this Aura enters, untap enchanted creature.
##         You control enchanted creature.
##         When enchanted creature dies, return that card to the battlefield under its owner's control.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Abduction", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen this Aura enters, untap enchanted creature.\nYou control enchanted creature.\nWhen enchanted creature dies, return that card to the battlefield under its owner's control.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
