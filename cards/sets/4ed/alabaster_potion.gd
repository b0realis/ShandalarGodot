extends CardScript
## Alabaster Potion — {X}{W}{W} — Instant — (4ed, common)
## Oracle: Choose one —
##         • Target player gains X life.
##         • Prevent the next X damage that would be dealt to any target
##           this turn.
##
## Implementation: Healing Salve's big sibling — the same two modes, both
## scaled by X (each mode's effect carries the x flag; the spell's X flows
## into whichever mode was chosen).


func build() -> CardData:
	return CardData.new("Alabaster Potion", "{X}{W}{W}", Mtg.CardType.INSTANT) \
		.mode("Target player gains X life",
			[GainLifeEffect.new(0).target_player().x_amount()]) \
		.mode("Prevent the next X damage to any target this turn",
			[PreventDamageEffect.new(0).any_target().x_amount()]) \
		.oracle("Choose one —\n• Target player gains X life.\n• Prevent the next X damage that would be dealt to any target this turn.")
