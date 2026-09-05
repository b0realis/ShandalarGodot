extends CardScript
## Detonate — {X}{R} — Sorcery — (4ed, uncommon)
## Oracle: Destroy target artifact with mana value X. It can't be
##         regenerated. Detonate deals X damage to that artifact's
##         controller.
##
## Implementation: "with mana value X" is a TARGETING restriction (CR
## 115.4), not a resolution check — a Detonate for 2 cannot legally be
## aimed at a three-drop in the first place. The filter is source-aware and
## reads MtgGame.casting_x, the one place that answers "what X is this card
## being cast for?" — the X a planner is trying on, or the announced one.
## Destruction is the no-regeneration kind, and the damage is dealt to
## whoever controlled the artifact.


func build() -> CardData:
	return CardData.new("Detonate", "{X}{R}", Mtg.CardType.SORCERY) \
		.spell(DetonateEffect.new()) \
		.oracle("Destroy target artifact with mana value X. It can't be regenerated. Detonate deals X damage to that artifact's controller.")


class DetonateEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"target artifact with mana value X", DetonateEffect._is_artifact)
		target_spec.with_source_filter(DetonateEffect._mana_value_is_x)

	static func _is_artifact(inst: CardInstance) -> bool:
		return inst.is_type(Mtg.CardType.ARTIFACT)

	## The X the caster is paying comes from [method MtgGame.casting_x],
	## which answers with the X a planner is TRYING ON while it sizes the
	## spell and with the announced one once it is really being cast — so
	## the restriction is enforced at cast time, re-checked when the spell
	## resolves, and answerable before a single land is tapped.
	static func _mana_value_is_x(game: MtgGame, source: CardInstance,
			inst: CardInstance) -> bool:
		return inst.data.cost.mana_value() == game.casting_x(source)

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, x_value: int = 0) -> void:
		var bomb := game.find_instance(target.instance_id)
		if bomb == null or bomb.zone != Mtg.Zone.BATTLEFIELD:
			return
		var owner := bomb.controller_id
		game.destroy(bomb, false)
		if x_value > 0:
			game.deal_damage(source, TargetRef.player(owner), x_value)

	func describe() -> String:
		return "destroys target artifact with mana value X and burns its controller for X"
