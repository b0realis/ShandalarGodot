extends CardScript
## Power Struggle — {2}{U}{U}{U} — Enchantment — (past, common)
## Oracle: During each player's upkeep, that player exchanges control of
##         random target artifact, creature or land he or she controls, for
##         control of random target permanent of the same type that a random
##         opponent controls.
##
## Implementation: at each upkeep the active player's own artifacts,
## creatures and lands are rolled for one victim; the opponent's permanents
## of the SAME type are rolled for its partner, and the two swap controllers.
## Nothing happens when either side has no matching permanent — the printed
## card needs both halves of the trade.


func build() -> CardData:
	return CardData.new("Power Struggle", "{2}{U}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _swap,
			"During each player's upkeep, that player exchanges control of a random permanent for one of the same type a random opponent controls.")) \
		.oracle("During each player's upkeep, that player exchanges control of random target artifact, creature or land he or she controls, for control of random target permanent of the same type that a random opponent controls.")


const SWAPPABLE := [Mtg.CardType.ARTIFACT, Mtg.CardType.CREATURE, Mtg.CardType.LAND]


static func _swap(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var mover := int(event.data["player"])
	var other := game.opponent_of(mover)
	var mine: Array = []
	for inst in game.players[mover].battlefield:
		for t in SWAPPABLE:
			if inst.is_type(t):
				mine.append(inst)
				break
	if mine.is_empty():
		return
	var given: Variant = RandomEffects.pick(game, mine)
	# The partner must share a type with the permanent being given away.
	var theirs: Array = []
	for inst in game.players[other].battlefield:
		for t in SWAPPABLE:
			if inst.is_type(t) and given.is_type(t):
				theirs.append(inst)
				break
	if theirs.is_empty():
		return
	var taken: Variant = RandomEffects.pick(game, theirs)
	game.change_control(given, other)
	game.change_control(taken, mover)
	game.log_line("Power Struggle trades %s for %s" % [given, taken])
