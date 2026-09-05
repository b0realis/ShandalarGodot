extends CardScript
## Pirate Ship — {4}{U} — Creature — Human Pirate — 4/3 (2ed, rare)
## Oracle: Pirate Ship can't attack unless defending player controls an
##         Island.
##         {T}: Pirate Ship deals 1 damage to any target.
##         When you control no Islands, sacrifice Pirate Ship.
##
## Implementation: the Sea Serpent attack clause + a Prodigal-style tap
## ping + with_sacrifice_if_no_land("island") for the drowning clause,
## enforced as a state-based action (wave 27 lifted the old ledger row).


func build() -> CardData:
	return CardData.new("Pirate Ship", "{4}{U}", Mtg.CardType.CREATURE) \
		.pt(4, 3) \
		.with_subtypes(["human", "pirate"]) \
		.with_attack_needs_defender_land("island") \
		.with_sacrifice_if_no_land("island") \
		.activated(ActivatedAbility.new(
			"", true,
			[DamageEffect.new(1).any_target()],
			"{T}: Pirate Ship deals 1 damage to any target.")) \
		.oracle("Pirate Ship can't attack unless defending player controls an Island.\n{T}: Pirate Ship deals 1 damage to any target.\nWhen you control no Islands, sacrifice Pirate Ship.")
