extends CardScript
## Fault Line — {X}{R}{R} — Instant (rare, usg).
## Oracle: Fault Line deals X damage to each creature without flying and each player.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fault Line", "{X}{R}{R}", Mtg.CardType.INSTANT)
	c.oracle("Fault Line deals X damage to each creature without flying and each player.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
