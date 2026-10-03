extends CardScript
## Prismatic Boon — {X}{W}{U} — Instant (uncommon, mir).
## Oracle: Choose a color. X target creatures gain protection from the chosen color until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Prismatic Boon", "{X}{W}{U}", Mtg.CardType.INSTANT)
	c.oracle("Choose a color. X target creatures gain protection from the chosen color until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
