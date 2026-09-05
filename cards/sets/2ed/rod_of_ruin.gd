extends CardScript
## Rod of Ruin — {4} — Artifact (2ed, uncommon)
## Oracle: {3}, {T}: This artifact deals 1 damage to any target.
##
## Implementation: mana+tap activated ability, DamageEffect(1).any_target().
## A colorless Prodigal Sorcerer that any deck can run — and being
## colorless, no protection-from-color stops its ping.


func build() -> CardData:
	return CardData.new("Rod of Ruin", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{3}", true,
			[DamageEffect.new(1).any_target()],
			"{3}, {T}: This artifact deals 1 damage to any target.")) \
		.oracle("{3}, {T}: This artifact deals 1 damage to any target.")
