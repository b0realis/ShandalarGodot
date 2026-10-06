extends CardScript
## Orim's Prayer — {1}{W}{W} — Enchantment (uncommon, tmp).
## Oracle: Whenever one or more creatures attack you, you gain 1 life for each attacking creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Orim's Prayer", "{1}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever one or more creatures attack you, you gain 1 life for each attacking creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
