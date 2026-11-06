extends CardScript
## Archery Training — {W} — Enchantment — Aura (uncommon, uds).
## Oracle: Enchant creature
##         At the beginning of your upkeep, you may put an arrow counter on this Aura.
##         Enchanted creature has "{T}: This creature deals X damage to target attacking or blocking creature, where X is the number of arrow counters on Archery Training."
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Archery Training", "{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nAt the beginning of your upkeep, you may put an arrow counter on this Aura.\nEnchanted creature has \"{T}: This creature deals X damage to target attacking or blocking creature, where X is the number of arrow counters on Archery Training.\"")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
