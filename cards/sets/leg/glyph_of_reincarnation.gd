extends CardScript
## Glyph of Reincarnation — {G} — Instant — (leg, common)
## Oracle: Cast this spell only after combat.
##         Destroy all creatures that were blocked by target Wall this
##         turn. They can't be regenerated. For each creature that died
##         this way, put a creature card from the graveyard of the player
##         who controlled that creature the last time it became blocked by
##         that Wall onto the battlefield under its owner's control.
##
## Implementation: the Wall's block history stores exactly what the second
## sentence asks for — {attacker id: the controller it had when it became
## blocked} — so the replacement bodies come out of the right graveyard.
## The raised creature enters under its OWNER's control, which is not
## necessarily the player whose graveyard it came from.
##
## The choice on resolution is the acting seat's own, asked through their
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The value the card
## computes is only the HINT, and the candidates are pre-sorted for it.


static func _is_wall(inst: CardInstance) -> bool:
	return inst.is_creature() and inst.has_subtype("wall")


## "Cast this spell only after combat" — after the whole COMBAT PHASE, so
## the postcombat main phase onwards. The end-of-combat step is still part
## of combat (CR 511), which is why the bar sits at MAIN2 and not at the
## combat damage step.
static func _after_combat(game: MtgGame, _pid: int) -> String:
	if Mtg.STEP_ORDER.find(game.current_step()) \
			< Mtg.STEP_ORDER.find(Mtg.Step.MAIN2):
		return "cast Glyph of Reincarnation only after combat"
	return ""


func build() -> CardData:
	return CardData.new("Glyph of Reincarnation", "{G}", Mtg.CardType.INSTANT) \
		.castable_only_when(_after_combat) \
		.spell(GlyphOfReincarnationEffect.new(
			TargetSpec.creature("target Wall creature", _is_wall).only_walls())) \
		.oracle("Cast this spell only after combat.\nDestroy all creatures that were blocked by target Wall this turn. They can't be regenerated. For each creature that died this way, put a creature card from the graveyard of the player who controlled that creature the last time it became blocked by that Wall onto the battlefield under its owner's control.")


class GlyphOfReincarnationEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		# CR 609.3: the Glyph's controller carries out its instructions.
		var wall := game.find_instance(target.instance_id)
		if wall == null:
			return
		var history: Dictionary = wall.blocked_ids_this_turn.duplicate()
		for attacker_id in history:
			var victim := game.find_instance(attacker_id)
			if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD:
				continue
			game.destroy(victim, false)
			if victim.zone != Mtg.Zone.GRAVEYARD:
				continue
			_raise_one(game, int(history[attacker_id]), _controller)

	## One replacement body out of [param pid]'s graveyard. WHICH card is
	## the SPELL's controller's choice (CR 609.3 — an effect's instructions
	## are carried out by the object's controller unless it says otherwise,
	## and this one only names whose graveyard to look in), which is not
	## the same seat: the Glyph's controller wants their opponent's WORST
	## body back, and the graveyard's owner would hand over their best.
	static func _raise_one(game: MtgGame, pid: int, chooser: int) -> void:
		var candidates: Array[CardInstance] = []
		for card in game.players[pid].graveyard:
			if card.data.is_creature():
				candidates.append(card)
		if candidates.is_empty():
			return
		# Sorted from the CHOOSER's point of view: their own graveyard's
		# biggest body first, an opponent's smallest first.
		if pid == chooser:
			candidates.sort_custom(GlyphOfReincarnationEffect._bigger_first)
		else:
			candidates.sort_custom(GlyphOfReincarnationEffect._smaller_first)
		var chosen := game.agents[chooser].choose_card(game, chooser, candidates,
			"Return a creature card to the battlefield")
		if chosen == null or not candidates.has(chosen):
			chosen = candidates[0]
		game.reanimate(chosen, chosen.owner_id)

	static func _bigger_first(a: CardInstance, b: CardInstance) -> bool:
		return a.data.power + a.data.toughness > b.data.power + b.data.toughness

	static func _smaller_first(a: CardInstance, b: CardInstance) -> bool:
		return a.data.power + a.data.toughness < b.data.power + b.data.toughness

	func describe() -> String:
		return "destroys everything target Wall blocked this turn and reincarnates them"
