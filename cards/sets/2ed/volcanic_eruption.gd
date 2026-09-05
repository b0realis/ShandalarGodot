extends CardScript
## Volcanic Eruption — {X}{U}{U}{U} — Sorcery — (2ed, rare)
## Oracle: Destroy X target Mountains. Volcanic Eruption deals damage to
##         each creature and each player equal to the number of Mountains
##         put into a graveyard this way.
##
## Implementation: one effect for both sentences — the second counts the
## Mountains the first actually buried, so a Mountain that was regenerated
## or had already left doesn't add to the blast. Destruction is plain
## destroy (Mountains may be regenerated, and the count then drops).


static func _is_mountain(inst: CardInstance) -> bool:
	return inst.is_land() and inst.has_subtype("mountain")


func build() -> CardData:
	# `subtype`: the filter asks for a land SUBTYPE, so that is the word
	# the 1997 refusal uses (`@PROMPT_ILLEGALTARGETWHY` entry 10, §6.10).
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Mountain",
		_is_mountain).because(TargetSpec.WHY["subtype"])
	return CardData.new("Volcanic Eruption", "{X}{U}{U}{U}", Mtg.CardType.SORCERY) \
		.spell(EruptEffect.new(spec)) \
		.oracle("Destroy X target Mountains. Volcanic Eruption deals damage to each creature and each player equal to the number of Mountains put into a graveyard this way.")


class EruptEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec
		x_targets()

	func resolve_multi(game: MtgGame, source: CardInstance, _controller: int,
			targets: Array, _x_value: int = 0) -> void:
		var buried := 0
		for ref in targets:
			var inst := game.find_instance(ref.instance_id)
			if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
				continue
			game.destroy(inst)
			if inst.zone == Mtg.Zone.GRAVEYARD:
				buried += 1
		if buried <= 0:
			return
		for inst in game.all_battlefield():
			if inst.is_creature():
				game.deal_damage(source, TargetRef.card(inst), buried)
		for p in game.players:
			if not p.has_lost:
				game.deal_damage(source, TargetRef.player(p.id), buried)

	func describe() -> String:
		return "destroys X target Mountains, then deals that much damage to each creature and each player"
