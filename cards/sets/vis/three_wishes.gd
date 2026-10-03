extends CardScript
## Three Wishes — {1}{U}{U} — Instant (rare, vis).
## Oracle: Exile the top three cards of your library face down. You may look at those cards for as long as they remain exiled. Until your next turn, you may play those cards. At the beginning of your next upkeep, put any of those cards you didn't play into your graveyard.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Three Wishes", "{1}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Exile the top three cards of your library face down. You may look at those cards for as long as they remain exiled. Until your next turn, you may play those cards. At the beginning of your next upkeep, put any of those cards you didn't play into your graveyard.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
