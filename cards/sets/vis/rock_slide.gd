extends CardScript
## Rock Slide — {X}{R} — Instant (common, vis).
## Oracle: Rock Slide deals X damage divided as you choose among any number of target attacking or blocking creatures without flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rock Slide", "{X}{R}", Mtg.CardType.INSTANT)
	c.oracle("Rock Slide deals X damage divided as you choose among any number of target attacking or blocking creatures without flying.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
