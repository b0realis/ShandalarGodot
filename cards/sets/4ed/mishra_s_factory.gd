extends CardScript
## Mishra's Factory — Land — (4ed, uncommon)
## Oracle: {T}: Add {C}.
##         {1}: This land becomes a 2/2 Assembly-Worker artifact creature
##         until end of turn. It's still a land.
##         {T}: Target Assembly-Worker creature gets +1/+1 until end of turn.
##
## Implementation: the engine's reference TYPE-CHANGING card and the reason
## rules code asks instances (is_creature()) instead of printed data.
## AnimateSelfEffect registers an until-EOT animation with the continuous
## pipeline: CREATURE|ARTIFACT added to cur_types, base P/T set 2/2,
## "assembly-worker" added to cur_subtypes — applied before counters/
## statics/pumps so Giant Growth on a Worker works. Summoning sickness now
## rides on EVERY entering permanent, so a Factory played this turn can
## animate but not attack (the famous judge call). The third ability makes
## Factories pump each other — the classic two-Factory 3/3 attack.


func build() -> CardData:
	var pump := PumpEffect.new(1, 1)
	pump.target_spec = TargetSpec.creature("target Assembly-Worker creature",
		_is_assembly_worker)
	return CardData.new("Mishra's Factory", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C)) \
		.activated(ActivatedAbility.new(
			"{1}", false,
			[AnimateSelfEffect.new(
				Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT, 2, 2,
				["assembly-worker"])],
			"{1}: Becomes a 2/2 Assembly-Worker artifact creature until end of turn.")) \
		.activated(ActivatedAbility.new(
			"", true,
			[pump],
			"{T}: Target Assembly-Worker creature gets +1/+1 until end of turn.")) \
		.oracle("{T}: Add {C}.\n{1}: This land becomes a 2/2 Assembly-Worker artifact creature until end of turn. It's still a land.\n{T}: Target Assembly-Worker creature gets +1/+1 until end of turn.")


static func _is_assembly_worker(inst: CardInstance) -> bool:
	return inst.has_subtype("assembly-worker")
