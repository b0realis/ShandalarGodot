extends CardScript
## Flash Counter — {1}{U} — Instant — (leg, common)
## Oracle: Counter target instant spell.
##
## Implementation: CounterEffect with a filter narrowing the SPELL target
## to instants. Two mana for a Counterspell that only answers half the
## game — but in a format full of Fogs and burn, that half matters.


func build() -> CardData:
	return CardData.new("Flash Counter", "{1}{U}", Mtg.CardType.INSTANT) \
		.spell(CounterEffect.new("target instant spell", _is_instant)) \
		.oracle("Counter target instant spell.")


static func _is_instant(inst: CardInstance) -> bool:
	return inst.data.is_type(Mtg.CardType.INSTANT)
