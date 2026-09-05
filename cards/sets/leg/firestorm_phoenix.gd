extends CardScript
## Firestorm Phoenix — {4}{R}{R} — Creature — Phoenix — 3/2 — (leg, rare)
## Oracle: Flying
##         If this creature would die, return it to its owner's hand
##         instead. Until that player's next turn, that player plays with
##         that card revealed in their hand and can't play it.
##
## Implementation: printed flying plus CardData.with_dies_to_hand(true) —
## a REPLACEMENT effect the engine applies inside _move_to_graveyard, so
## nothing sees the Phoenix die (no dies-triggers, no corpse for Animate
## Dead). The `true` is the rider: as the card lands in its owner's hand
## the engine stamps it (CardInstance.hand_lock_turn / revealed_in_hand —
## MtgGame._lock_in_hand), cast_spell refuses it ("can't be played until
## your next turn") and the lock lifts as its OWNER's next turn begins
## (MtgGame._end_turn → _release_hand_locks): a Phoenix that dies on its
## owner's own turn sits out the rest of that turn and the opponent's
## whole turn. The lock belongs to the card's stay in that hand — should
## it be discarded and later returned it is a new object (CR 400.7) and
## plays freely. The revealed flag is public information for the duel
## screen and the AI; the engine itself keeps no secrets from either.


func build() -> CardData:
	return CardData.new("Firestorm Phoenix", "{4}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(3, 2) \
		.with_subtypes(["phoenix"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.with_dies_to_hand(true) \
		.oracle("Flying\nIf this creature would die, return it to its owner's hand "
			+ "instead. Until that player's next turn, that player plays with that "
			+ "card revealed in their hand and can't play it.")
