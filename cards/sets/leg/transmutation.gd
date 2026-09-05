extends CardScript
## Transmutation — {1}{B} — Instant — (leg, common)
## Oracle: Switch target creature's power and toughness until end of turn.
##
## Implementation: SwitchPowerToughnessEffect, applied in the final P/T
## sublayer (CR 613.4e) — so it reads whatever the creature's power and
## toughness are at the moment of every recalculation, and a later Giant
## Growth pumps the switched values. Aimed at a 0/X wall it is removal.


func build() -> CardData:
	return CardData.new("Transmutation", "{1}{B}", Mtg.CardType.INSTANT) \
		.spell(SwitchPowerToughnessEffect.new()) \
		.oracle("Switch target creature's power and toughness until end of turn.")
