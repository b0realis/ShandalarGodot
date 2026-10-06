extends CardScript
## Hidden Retreat — {2}{W} — Enchantment (rare, sth).
## Oracle: Put a card from your hand on top of your library: Prevent all damage that would be dealt by target instant or sorcery spell this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hidden Retreat", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Put a card from your hand on top of your library: Prevent all damage that would be dealt by target instant or sorcery spell this turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
