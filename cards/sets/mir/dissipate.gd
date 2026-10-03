extends CardScript
## Dissipate — {1}{U}{U} — Instant (uncommon, mir).
## Oracle: Counter target spell. If that spell is countered this way, exile it instead of putting it into its owner's graveyard.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dissipate", "{1}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target spell. If that spell is countered this way, exile it instead of putting it into its owner's graveyard.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
