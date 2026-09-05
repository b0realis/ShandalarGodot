extends CardScript
## Alchor's Tomb — {4} — Artifact — (leg, rare)
## Oracle: {2}, {T}: Target permanent you control becomes the color of your
##         choice. (This effect lasts indefinitely.)
##
## Implementation: an INDEFINITE colour change on a permanent you control.
## The colour comes from the DecisionAgent (choose_color) with a hint the
## card computes itself — the colour the opponent's board shows LEAST of,
## which is the repaint most likely to dodge their colour hosers and their
## Terror-style filters.


static func _yours(_game: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == source.controller_id


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent you control")
	spec.with_source_filter(_yours)
	return CardData.new("Alchor's Tomb", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{2}", true, [RepaintEffect.new(spec)],
			"{2}, {T}: Target permanent you control becomes the color of your choice.")) \
		.oracle("{2}, {T}: Target permanent you control becomes the color of your choice. (This effect lasts indefinitely.)")


class RepaintEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		var hint := _rarest_enemy_color(game, controller)
		var chosen: int = game.agents[controller].choose_color(
			game, controller, "Choose a color for %s" % inst.data.card_name, hint)
		game.set_color(inst, chosen)

	## The colour the opponent's board shows least of — the safest repaint.
	static func _rarest_enemy_color(game: MtgGame, controller: int) -> int:
		var enemy := game.opponent_of(controller)
		var best: int = Mtg.ManaColor.W
		var best_count := -1
		for color in Mtg.WUBRG:
			var count := 0
			for inst in game.players[enemy].battlefield:
				if inst.has_color(color):
					count += 1
			if best_count < 0 or count < best_count:
				best = color
				best_count = count
		return best

	func describe() -> String:
		return "target permanent you control becomes the color of your choice"
