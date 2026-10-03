extends CardScript
## Reality Ripple — {1}{U} — Instant (common, mir).
## Oracle: Target artifact, creature, or land phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before its controller untaps during their next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reality Ripple", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("Target artifact, creature, or land phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before its controller untaps during their next untap step.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
