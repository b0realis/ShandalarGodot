extends CardScript
## Betrayal — {U} — Enchantment — Aura (common, vis).
## Oracle: Enchant creature an opponent controls
##         Whenever enchanted creature becomes tapped, you draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Betrayal", "{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature an opponent controls\nWhenever enchanted creature becomes tapped, you draw a card.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
