extends CardScript
## Turnabout — {2}{U}{U} — Instant (uncommon, usg).
## Oracle: Choose artifact, creature, or land. Tap all untapped permanents of the chosen type target player controls, or untap all tapped permanents of that type that player controls.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Turnabout", "{2}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Choose artifact, creature, or land. Tap all untapped permanents of the chosen type target player controls, or untap all tapped permanents of that type that player controls.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
