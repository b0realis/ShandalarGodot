extends CardScript
## Priest of Yawgmoth — {1}{B} — Creature — Phyrexian Human Cleric — 1/2 — (atq, common)
## Oracle: {T}, Sacrifice an artifact: Add an amount of {B} equal to the
##         sacrificed artifact's mana value.
##
## Implementation: a ManaAbility (CR 605.1a — no target, adds mana) whose
## cost includes {T} and "Sacrifice an artifact", and whose output SCALES
## with the eaten artifact's mana value
## (ManaAbility.scaling_with_sacrifice). Being stackless it can convert an
## artifact into black mana in the middle of casting a spell.


func build() -> CardData:
	return CardData.new("Priest of Yawgmoth", "{1}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_subtypes(["phyrexian", "human", "cleric"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.B, 0) \
			.with_sacrifice_of("artifact", _is_artifact) \
			.scaling_with_sacrifice()) \
		.oracle("{T}, Sacrifice an artifact: Add an amount of {B} equal to the "
			+ "sacrificed artifact's mana value.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)
