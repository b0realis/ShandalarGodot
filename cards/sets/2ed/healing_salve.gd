extends CardScript
## Healing Salve — {W} — Instant — (2ed, common)
## Oracle: Choose one —
##         • Target player gains 3 life.
##         • Prevent the next 3 damage that would be dealt to any target
##           this turn.
##
## Implementation: the engine's reference MODAL spell (CardData.modes; the
## mode index is chosen at cast time and travels on the StackItem). Mode 0
## is a targeted GainLifeEffect; mode 1 is the new amount-based
## PreventDamageEffect — a this-turn pool on the target that
## MtgGame.deal_damage drains point for point. One third of the original
## "boon" cycle with Giant Growth and Dark Ritual.


func build() -> CardData:
	return CardData.new("Healing Salve", "{W}", Mtg.CardType.INSTANT) \
		.mode("Target player gains 3 life", [GainLifeEffect.new(3).target_player()]) \
		.mode("Prevent the next 3 damage to any target this turn",
			[PreventDamageEffect.new(3).any_target()]) \
		.oracle("Choose one —\n• Target player gains 3 life.\n• Prevent the next 3 damage that would be dealt to any target this turn.")
