extends CardScript
## City of Solitude — {2}{G} — Enchantment (rare, vis).
## Oracle: Players can cast spells and activate abilities only during their own turns.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("City of Solitude", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Players can cast spells and activate abilities only during their own turns.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
