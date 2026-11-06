extends CardScript
## Ashnod's Transmogrant — {1} — Artifact — (atq, uncommon)
## Oracle: {T}, Sacrifice this artifact: Put a +1/+1 counter on target
##         nonartifact creature. That creature becomes an artifact in
##         addition to its other types.
##
## Implementation: a one-shot artifact (tap + sacrifice itself) that
## leaves behind a +1/+1 counter AND a type change with no duration — "in
## addition to its other types" (CR 205.1b), stamped on the layer-4 clock
## as the ability resolves (ContinuousEffects.add_type_change, retaining
## the other types) and kept until the creature leaves the battlefield. So
## a type change made BEFORE it (an awakened Opal Caryatid's "becomes a 2/2
## Soldier creature") cannot overwrite it and one made AFTER it (Soul
## Sculptor) does (CR 613.7; 0.60.19 bug pass, h2-1 — it used to be a
## printed-type grant, applied before every layer-4 effect). Turning your
## own creature into an artifact is a real cost — Shatterstorm now kills
## it.


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
		game.continuous.add_type_change(inst.id,
			{"set_types": Mtg.CardType.ARTIFACT, "retain_types": true})
		game.add_counters(inst, "+1/+1", 1)
		game.recalculate()

	func describe() -> String:
		return "puts a +1/+1 counter on target nonartifact creature and makes it an artifact"
