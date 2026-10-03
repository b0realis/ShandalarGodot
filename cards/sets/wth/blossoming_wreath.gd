extends CardScript
## Blossoming Wreath — {G} — Instant (common, wth).
## Oracle: You gain life equal to the number of creature cards in your graveyard.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Blossoming Wreath", "{G}", Mtg.CardType.INSTANT)
	c.oracle("You gain life equal to the number of creature cards in your graveyard.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
