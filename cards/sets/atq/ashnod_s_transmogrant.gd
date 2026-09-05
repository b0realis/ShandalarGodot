extends CardScript
## Ashnod's Transmogrant — {1} — Artifact — (atq, uncommon)
## Oracle: {T}, Sacrifice this artifact: Put a +1/+1 counter on target
##         nonartifact creature. That creature becomes an artifact in
##         addition to its other types.
##
## Implementation: a one-shot artifact (tap + sacrifice itself) that
## leaves behind a +1/+1 counter AND a permanent type grant, stored in
## CardInstance.added_types so it survives every recalculation until the
## creature leaves the battlefield. Turning your own creature into an
## artifact is a real cost — Shatterstorm now kills it.


func build() -> CardData:
	var spec := TargetSpec.creature("target nonartifact creature", _is_nonartifact)
	return CardData.new("Ashnod's Transmogrant", "{1}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"", true, [TransmogrifyEffect.new(spec)],
			"{T}, Sacrifice Ashnod's Transmogrant: Put a +1/+1 counter on target "
			+ "nonartifact creature. That creature becomes an artifact in addition to "
			+ "its other types.") \
			.with_sacrifice_cost()) \
		.oracle("{T}, Sacrifice this artifact: Put a +1/+1 counter on target "
			+ "nonartifact creature. That creature becomes an artifact in addition to "
			+ "its other types.")


static func _is_nonartifact(inst: CardInstance) -> bool:
	return not inst.is_type(Mtg.CardType.ARTIFACT)


class TransmogrifyEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		inst.added_types |= Mtg.CardType.ARTIFACT
		game.add_counters(inst, "+1/+1", 1)

	func describe() -> String:
		return "puts a +1/+1 counter on target nonartifact creature and makes it an artifact"
