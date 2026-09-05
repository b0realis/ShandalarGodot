extends CardScript
## Mana Vortex — {1}{U}{U} — Enchantment — (drk, rare)
## Oracle: When you cast this spell, counter it unless you sacrifice a land.
##         At the beginning of each player's upkeep, that player sacrifices
##         a land of their choice.
##         When there are no lands on the battlefield, sacrifice this
##         enchantment.
##
## Implementation: three clauses, three engine pieces.
## - The entry toll is a CAST TRIGGER, as printed: a SPELL_CAST trigger
##   the spell itself hears while on the stack (MtgGame.cast_spell hands
##   the spell to dispatch_event as a listener), so the Vortex is cast, the
##   trigger goes on the stack above it, both players may respond, and on
##   resolution the caster is asked for a land (choose_card, optional —
##   "unless you sacrifice"; the heuristic gives one up when it has one)
##   and the Vortex is countered when none is given. A player with no
##   land may cast it and watch it be countered; a land removed in
##   response leaves nothing to sacrifice. Lifted 2026-09-02; it used to
##   be an additional cost that refused the cast outright.
## - The grind is an upkeep trigger with no controller condition, so it
##   fires on EVERY player's upkeep — which is the whole card.
## - "When there are no lands on the battlefield" is
##   CardData.sacrifices_when, a state-based check, so the Vortex eats
##   itself the moment the board runs dry rather than waiting for an upkeep.


func build() -> CardData:
	return CardData.new("Mana Vortex", "{1}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.SPELL_CAST, _toll,
			"When you cast this spell, counter it unless you sacrifice a land.",
			_own_cast)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _grind,
			"At the beginning of each player's upkeep, that player sacrifices a land of their choice.")) \
		.sacrifices_when(_no_lands_left) \
		.oracle("When you cast this spell, counter it unless you sacrifice a land."
			+ "\nAt the beginning of each player's upkeep, that player sacrifices a "
			+ "land of their choice.\nWhen there are no lands on the battlefield, "
			+ "sacrifice this enchantment.")


static func _own_cast(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source and source.zone == Mtg.Zone.STACK


static func _toll(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.STACK:
		return   # already countered or otherwise gone: nothing to do
	var pid := source.controller_id
	var lands := _lands_of(game, pid)
	var pick: CardInstance = null
	if not lands.is_empty():
		pick = game.agents[pid].choose_card(game, pid, lands,
			"Sacrifice a land, or Mana Vortex is countered", true)
		if pick != null and not lands.has(pick):
			pick = lands[0]
	if pick == null:
		game.counter_spell(source)
		return
	game.sacrifice_permanent(pick)


static func _no_lands_left(game: MtgGame, _source: CardInstance) -> bool:
	for inst in game.all_battlefield():
		if inst.is_land():
			return false
	return true


static func _grind(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var lands := _lands_of(game, pid)
	if lands.is_empty():
		return
	var pick := game.agents[pid].choose_card(game, pid, lands, "Sacrifice a land")
	if pick == null or not lands.has(pick):
		pick = lands[0]
	game.sacrifice_permanent(pick)


## That player's lands, basics first — the head of the list is what the
## heuristic gives up.
static func _lands_of(game: MtgGame, pid: int) -> Array[CardInstance]:
	var lands: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_land():
			lands.append(inst)
	lands.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var ab := (a.data.supertypes & Mtg.Supertype.BASIC) != 0
		var bb := (b.data.supertypes & Mtg.Supertype.BASIC) != 0
		if ab != bb:
			return ab
		return a.id < b.id)
	return lands
