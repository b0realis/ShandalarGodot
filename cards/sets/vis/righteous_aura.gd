extends CardScript
## Righteous Aura — {1}{W} — Enchantment (common, vis).
## Oracle: {W}, Pay 2 life: The next time a source of your choice would deal damage to you this turn, prevent that damage.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Righteous Aura", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{W}, Pay 2 life: The next time a source of your choice would deal damage to you this turn, prevent that damage.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
