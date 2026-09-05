extends CardScript
## Jump — {U} — Instant (2ed, common)
## Oracle: Target creature gains flying until end of turn.
##
## Implementation: PumpEffect(0, 0, [FLYING]) — a zero-stat pump whose
## whole payload is the granted keyword, expiring at cleanup with every
## other until-end-of-turn effect. Combat surprise: a Jumped blocker can
## catch an attacking flyer.


func build() -> CardData:
	return CardData.new("Jump", "{U}", Mtg.CardType.INSTANT) \
		.spell(PumpEffect.new(0, 0, [Mtg.Keyword.FLYING])) \
		.oracle("Target creature gains flying until end of turn.")
