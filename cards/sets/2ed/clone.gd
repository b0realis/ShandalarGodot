extends CardScript
## Clone — {3}{U} — Creature — Shapeshifter — 0/0 — (2ed, uncommon)
## Oracle: You may have this creature enter as a copy of any creature on
##         the battlefield.
##
## Implementation: a true REPLACEMENT effect (CR 614.1c) — the engine
## applies it as the Clone enters, so its printed 0/0 body is never on the
## battlefield for state-based actions to bury. Copying repoints the
## instance's definition (CR 707: copiable values), so the Clone gets the
## original's name, P/T, keywords, abilities and statics; leaving the
## battlefield turns it back into a Clone.
##
## The choice on resolution is the acting seat's own, asked through their
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The value the card
## computes is only the HINT, and the candidates are pre-sorted for it.


static func _any_creature(inst: CardInstance) -> bool:
	return inst.is_creature()


func build() -> CardData:
	return CardData.new("Clone", "{3}{U}", Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.with_subtypes(["shapeshifter"]) \
		.with_enters_as_copy(_any_creature, "any creature on the battlefield") \
		.oracle("You may have this creature enter as a copy of any creature on the battlefield.")
