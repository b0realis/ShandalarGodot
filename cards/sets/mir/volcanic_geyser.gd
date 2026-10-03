extends CardScript
## Volcanic Geyser — {X}{R}{R} — Instant (uncommon, mir).
## Oracle: Volcanic Geyser deals X damage to any target.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Volcanic Geyser", "{X}{R}{R}", Mtg.CardType.INSTANT)
	c.oracle("Volcanic Geyser deals X damage to any target.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
