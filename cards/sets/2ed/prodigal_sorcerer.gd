extends CardScript
## Prodigal Sorcerer — {2}{U} — Creature — Human Wizard Sorcerer — 1/1 (Alpha, common)
## Oracle: {T}: Prodigal Sorcerer deals 1 damage to any target.
##
## Implementation: an ActivatedAbility with a tap cost and a 1-damage
## effect. Summoning sickness applies to the tap activation (CR 602.5g) —
## the engine refuses activation the turn it arrives; the test suite
## covers exactly that. "Tim" to its friends.


func build() -> CardData:
	return CardData.new("Prodigal Sorcerer", "{2}{U}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "wizard", "sorcerer"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[DamageEffect.new(1).any_target()],
			"{T}: Prodigal Sorcerer deals 1 damage to any target.")) \
		.oracle("{T}: Prodigal Sorcerer deals 1 damage to any target.")
