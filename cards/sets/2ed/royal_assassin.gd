extends CardScript
## Royal Assassin — {1}{B}{B} — Creature — Human Assassin — 1/1 (2ed, rare)
## Oracle: {T}: Destroy target tapped creature.
##
## Implementation: activated tap ability + a filtered DestroyEffect whose
## predicate reads LIVE tapped state. The classic play pattern works out of
## the box: an opponent attacks with a non-vigilance creature, it taps, the
## assassin (untapped, past summoning sickness) executes it during the
## declare-attackers priority round.


func build() -> CardData:
	var spec := TargetSpec.creature("target tapped creature", _is_tapped)
	return CardData.new("Royal Assassin", "{1}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "assassin"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[DestroyEffect.new(spec)],
			"{T}: Destroy target tapped creature.")) \
		.oracle("{T}: Destroy target tapped creature.")


static func _is_tapped(inst: CardInstance) -> bool:
	return inst.tapped
