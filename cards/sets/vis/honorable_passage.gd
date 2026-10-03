extends CardScript
## Honorable Passage — {1}{W} — Instant (uncommon, vis).
## Oracle: The next time a source of your choice would deal damage to any target this turn, prevent that damage. If damage from a red source is prevented this way, Honorable Passage deals that much damage to the source's controller.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Honorable Passage", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("The next time a source of your choice would deal damage to any target this turn, prevent that damage. If damage from a red source is prevented this way, Honorable Passage deals that much damage to the source's controller.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
