extends CardScript
## Doomsday — {B}{B}{B} — Sorcery (rare, wth).
## Oracle: Search your library and graveyard for five cards and exile the rest. Put the chosen cards on top of your library in any order. You lose half your life, rounded up.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Doomsday", "{B}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Search your library and graveyard for five cards and exile the rest. Put the chosen cards on top of your library in any order. You lose half your life, rounded up.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
