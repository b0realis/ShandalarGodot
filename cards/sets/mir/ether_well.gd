extends CardScript
## Ether Well — {3}{U} — Instant (uncommon, mir).
## Oracle: Put target creature on top of its owner's library. If that creature is red, you may put it on the bottom of its owner's library instead.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ether Well", "{3}{U}", Mtg.CardType.INSTANT)
	c.oracle("Put target creature on top of its owner's library. If that creature is red, you may put it on the bottom of its owner's library instead.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
