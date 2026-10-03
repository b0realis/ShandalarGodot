extends CardScript
## Disempower — {1}{W} — Instant (common, mir).
## Oracle: Put target artifact or enchantment on top of its owner's library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Disempower", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Put target artifact or enchantment on top of its owner's library.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
