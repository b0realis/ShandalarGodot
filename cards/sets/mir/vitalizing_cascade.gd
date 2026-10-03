extends CardScript
## Vitalizing Cascade — {X}{G}{W} — Instant (uncommon, mir).
## Oracle: You gain X plus 3 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vitalizing Cascade", "{X}{G}{W}", Mtg.CardType.INSTANT)
	c.oracle("You gain X plus 3 life.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
