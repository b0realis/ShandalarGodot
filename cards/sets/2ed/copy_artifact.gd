extends CardScript
## Copy Artifact — {1}{U} — Enchantment — (2ed, rare)
## Oracle: You may have this enchantment enter as a copy of any artifact on
##         the battlefield, except it's an enchantment in addition to its
##         other types.
##
## Implementation: the same enters-as-a-copy replacement Clone uses, with
## ENCHANTMENT OR'd into the copy's types (CardInstance.added_types, which
## survives every recalculation) — so it is still hit by Disenchant either
## way, and a copied mana rock really taps for mana.
##
## The choice on resolution is the acting seat's own, asked through their
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The value the card
## computes is only the HINT, and the candidates are pre-sorted for it.


static func _any_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


func build() -> CardData:
	return CardData.new("Copy Artifact", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.with_enters_as_copy(_any_artifact, "any artifact on the battlefield",
			Mtg.CardType.ENCHANTMENT) \
		.oracle("You may have this enchantment enter as a copy of any artifact on the battlefield, except it's an enchantment in addition to its other types.")
