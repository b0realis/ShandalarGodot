extends CardScript
## Counterspell — {U}{U} — Instant (2ed, uncommon)
## Oracle: Counter target spell.
##
## Implementation: CounterEffect targeting a spell on the stack
## (TargetSpec.Kind.SPELL). Timing falls out of the engine's priority
## rules: after an opponent casts, you receive priority and can respond;
## on resolution the target spell's stack item vanishes and the card goes
## to its owner's graveyard with no effect (CR 701.5a). Countering a
## Counterspell works (it's a spell on the stack like any other).


func build() -> CardData:
	return CardData.new("Counterspell", "{U}{U}", Mtg.CardType.INSTANT) \
		.spell(CounterEffect.new()) \
		.oracle("Counter target spell.")
