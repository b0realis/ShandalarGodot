extends CardScript
## Touch of Darkness — {B} — Instant — (leg, uncommon)
## Oracle: One or more target creatures become black until end of turn.
##
## Implementation: a variable-count target group (one or more) plus an
## UNTIL-END-OF-TURN colour change — the floating half of the colour layer,
## expired with every other until-EOT effect at cleanup. The default
## EffectBase.resolve_multi repaints each chosen creature in turn.


func build() -> CardData:
	return CardData.new("Touch of Darkness", "{B}", Mtg.CardType.INSTANT) \
		.spell(ChangeColorEffect.new(Mtg.ManaColor.B, TargetSpec.creature()) \
			.until_end_of_turn().one_or_more()) \
		.oracle("One or more target creatures become black until end of turn.")
