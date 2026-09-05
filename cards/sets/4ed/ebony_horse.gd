extends CardScript
## Ebony Horse — {3} — Artifact — (4ed, rare)
## Oracle: {2}, {T}: Untap target attacking creature you control. Prevent
##         all combat damage that would be dealt to and dealt by that
##         creature this turn.
##
## Implementation: one card-local effect (the printed card has a single
## target both sentences share) — untap plus a floating combat-damage
## prevention in BOTH directions. Attack with everything, then untap your
## best blocker; it deals no damage this turn, but it survives anything.


func build() -> CardData:
	var spec := TargetSpec.creature("target attacking creature you control")
	spec.with_source_filter(_your_attacker)
	return CardData.new("Ebony Horse", "{3}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", true, [RecallEffect.new(spec)],
			"{2}, {T}: Untap target attacking creature you control. Prevent all "
			+ "combat damage that would be dealt to and dealt by that creature this turn.")) \
		.oracle("{2}, {T}: Untap target attacking creature you control. Prevent all "
			+ "combat damage that would be dealt to and dealt by that creature this turn.")


static func _your_attacker(game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return inst.controller_id == source.controller_id \
		and game.combat.attackers.has(inst.id)


class RecallEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.untap_permanent(inst)
		game.continuous.add_until_eot_combat_prevention(inst.id, true, true)
		game.recalculate()

	func describe() -> String:
		return "untaps an attacker of yours and blanks its combat damage both ways"
