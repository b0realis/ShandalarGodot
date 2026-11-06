extends CardScript
## Treachery — {3}{U}{U} — Enchantment — Aura (rare, uds).
## Oracle: Enchant creature
##         When this Aura enters, untap up to five lands.
##         You control enchanted creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Treachery", "{3}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen this Aura enters, untap up to five lands.\nYou control enchanted creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
