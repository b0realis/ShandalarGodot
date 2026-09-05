extends CardScript
## Ashnod's Altar — {3} — Artifact — (atq, uncommon)
## Oracle: Sacrifice a creature: Add {C}{C}.
##
## Implementation: a MANA ability (CR 605.1a — no target, adds mana) whose
## whole cost is "Sacrifice a creature", with NO {T}: the Altar never taps
## and can be activated as often as there are bodies. Being stackless it
## can also be used in the middle of paying for a spell, which is the
## whole point of the card. The body is chosen by the controller's
## DecisionAgent.


func build() -> CardData:
	return CardData.new("Ashnod's Altar", "{3}", Mtg.CardType.ARTIFACT) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 2).without_tap() \
			.with_sacrifice_of("creature", _is_creature)) \
		.oracle("Sacrifice a creature: Add {C}{C}.")


static func _is_creature(inst: CardInstance) -> bool:
	return inst.is_creature()
