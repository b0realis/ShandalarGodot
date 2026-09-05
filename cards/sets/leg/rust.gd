extends CardScript
## Rust — {G} — Instant — (leg, common)
## Oracle: Counter target activated ability from an artifact source.
##         (Mana abilities can't be targeted.)
##
## Implementation: the pool's first user of TargetSpec.Kind.ABILITY — an
## activated ability on the stack is an object in its own right (CR 113.3b)
## and is targeted through its StackItem, because several activations of one
## Icy Manipulator can be waiting at once.
##
## The reminder text needs no code: a mana ability never uses the stack
## (CR 605.3a), so it is never a candidate.
##
## Countering an ability puts no card anywhere (there is no card) and
## refunds nothing — the {1} and the tap that bought the Icy Manipulator's
## freeze are gone either way, which is exactly why one green instant for a
## whole artifact activation was worth printing.


func build() -> CardData:
	return CardData.new("Rust", "{G}", Mtg.CardType.INSTANT) \
		.spell(CounterAbilityEffect.new(
			"target activated ability from an artifact source",
			CounterAbilityEffect.from_an_artifact)) \
		.oracle("Counter target activated ability from an artifact source. "
			+ "(Mana abilities can't be targeted.)")
