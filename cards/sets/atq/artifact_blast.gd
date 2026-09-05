extends CardScript
## Artifact Blast — {R} — Instant — (atq, common)
## Oracle: Counter target artifact spell.
##
## Implementation: CounterEffect with a filter narrowing the SPELL target
## to artifacts (artifact creatures too — the filter reads the printed
## type mask of a card on the stack). One red mana to blank a Mox, a Sol
## Ring or a Juggernaut before it ever lands.


func build() -> CardData:
	return CardData.new("Artifact Blast", "{R}", Mtg.CardType.INSTANT) \
		.spell(CounterEffect.new("target artifact spell", _is_artifact)) \
		.oracle("Counter target artifact spell.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.data.is_type(Mtg.CardType.ARTIFACT)
