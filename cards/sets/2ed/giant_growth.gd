extends CardScript
## Giant Growth — {G} — Instant (Alpha, common)
## Oracle: Target creature gets +3/+3 until end of turn.
##
## Implementation: PumpEffect — resolving registers an until-end-of-turn
## floating effect with the continuous pipeline; the cleanup step expires
## it. Note the classic interaction this models correctly: bolting a bear
## in response to Growth still kills nothing once the Growth resolves
## (5 toughness vs 3 marked damage), but if the Growth expires with the
## damage still marked... damage also wears off at cleanup, so both go
## together (CR 514.2).


func build() -> CardData:
	return CardData.new("Giant Growth", "{G}", Mtg.CardType.INSTANT) \
		.spell(PumpEffect.new(3, 3)) \
		.oracle("Target creature gets +3/+3 until end of turn.")
