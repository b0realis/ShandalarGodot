extends CardScript
## Wellspring — {1}{G}{W} — Enchantment — Aura (rare, mir).
## Oracle: Enchant land
##         When this Aura enters, gain control of enchanted land until end of turn.
##         At the beginning of your upkeep, untap enchanted land. You gain control of that land until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wellspring", "{1}{G}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant land\nWhen this Aura enters, gain control of enchanted land until end of turn.\nAt the beginning of your upkeep, untap enchanted land. You gain control of that land until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
