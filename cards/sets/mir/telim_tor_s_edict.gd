extends CardScript
## Telim'Tor's Edict — {R} — Instant (rare, mir).
## Oracle: Exile target permanent you own or control.
##         Draw a card at the beginning of the next turn's upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Telim'Tor's Edict", "{R}", Mtg.CardType.INSTANT)
	c.oracle("Exile target permanent you own or control.\nDraw a card at the beginning of the next turn's upkeep.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
