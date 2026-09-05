extends CardScript
## Fork — {R}{R} — Instant — (2ed, rare)
## Oracle: Copy target instant or sorcery spell, except that the copy is
##         red. You may choose new targets for the copy.
##
## Implementation: the copy is a real object on the stack under Fork's
## controller — not a card, so it ceases to exist when it finishes
## resolving (CR 707.10a) — and it is painted red with the wave-44 colour
## layer, which matters against Circles of Protection and red hosers.
##
## "You may choose new targets for the copy" (CR 707.10c) is Fork's
## controller's choice, made as Fork resolves (MtgGame.offer_new_targets):
## one question per target slot of the copied spell, from everything
## legal for that slot right now — the copy keeps the original's NUMBER of
## targets and its X (Duel.hlp, Fork: "you choose the copy's targets" ...
## "the controller of the copy must use the same number of targets the
## original spell did"). The list leads with the opponent's face when a
## player may be named (what a caster forking a burn spell wants — the
## heuristic's answer), else the original's own target when it is still
## legal; a slot with a single legal candidate is kept without asking.


static func _instant_or_sorcery(inst: CardInstance) -> bool:
	# The LIVE types (CONTRIBUTING.md rule 5), not the printed ones.
	return inst.is_type(Mtg.CardType.INSTANT) \
		or inst.is_type(Mtg.CardType.SORCERY)


func build() -> CardData:
	return CardData.new("Fork", "{R}{R}", Mtg.CardType.INSTANT) \
		.spell(ForkEffect.new(TargetSpec.spell(
			"target instant or sorcery spell", _instant_or_sorcery))) \
		.oracle("Copy target instant or sorcery spell, except that the copy is red. You may choose new targets for the copy.")


class ForkEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var original := game.find_instance(target.instance_id)
		if original == null or original.zone != Mtg.Zone.STACK:
			return
		var item := game.find_stack_item(original)
		if item == null:
			return
		var copy := game.copy_spell_on_stack(original, controller)
		if copy == null:
			return
		game.set_color(copy, Mtg.ManaColor.R)
		# Painted red BEFORE the targets are offered: a creature with
		# protection from red is not a legal target for the copy.
		game.offer_new_targets(copy, controller, game.opponent_of(controller))

	func describe() -> String:
		return "copies target instant or sorcery spell; the copy is red"
