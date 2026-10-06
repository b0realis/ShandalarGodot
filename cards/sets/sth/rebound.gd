extends CardScript
## Rebound — {1}{U} — Instant (uncommon, sth).
## Oracle: Change the target of target spell that targets only a player. The new target must be a player.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rebound", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("Change the target of target spell that targets only a player. The new target must be a player.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
