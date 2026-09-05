extends CardScript
## Remove Soul — {1}{U} — Instant — (leg, common)
## Oracle: Counter target creature spell.
##
## Implementation: CounterEffect with a creature-spell filter — the target
## must be a spell on the stack whose printed types include CREATURE. The
## AI's _try_counter validates the filter before committing, so it never
## wastes Remove Soul pointing at a sorcery. Blue's budget Counterspell
## against creature decks.


func build() -> CardData:
	return CardData.new("Remove Soul", "{1}{U}", Mtg.CardType.INSTANT) \
		.spell(CounterEffect.new("target creature spell", _is_creature_spell)) \
		.oracle("Counter target creature spell.")


static func _is_creature_spell(inst: CardInstance) -> bool:
	return inst.data.is_creature()
