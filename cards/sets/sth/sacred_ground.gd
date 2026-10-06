extends CardScript
## Sacred Ground — {1}{W} — Enchantment (rare, sth).
## Oracle: Whenever a spell or ability an opponent controls causes a land to be put into your graveyard from the battlefield, return that card to the battlefield.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sacred Ground", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a spell or ability an opponent controls causes a land to be put into your graveyard from the battlefield, return that card to the battlefield.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
