extends CardScript
## Worthy Cause — {W} — Instant (uncommon, tmp).
## Oracle: Buyback {2} (You may pay an additional {2} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         As an additional cost to cast this spell, sacrifice a creature.
##         You gain life equal to the sacrificed creature's toughness.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Worthy Cause", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {2} (You may pay an additional {2} as you cast this spell. If you do, put this card into your hand as it resolves.)\nAs an additional cost to cast this spell, sacrifice a creature.\nYou gain life equal to the sacrificed creature's toughness.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
