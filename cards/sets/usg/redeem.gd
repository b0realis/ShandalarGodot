extends CardScript
## Redeem — {1}{W} — Instant (uncommon, usg).
## Oracle: Prevent all damage that would be dealt this turn to up to two target creatures.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Redeem", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Prevent all damage that would be dealt this turn to up to two target creatures.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
