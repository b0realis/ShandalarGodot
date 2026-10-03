extends CardScript
## Shadowbane — {1}{W} — Instant (uncommon, mir).
## Oracle: The next time a source of your choice would deal damage to you and/or creatures you control this turn, prevent that damage. If damage from a black source is prevented this way, you gain that much life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shadowbane", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("The next time a source of your choice would deal damage to you and/or creatures you control this turn, prevent that damage. If damage from a black source is prevented this way, you gain that much life.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
