extends CardScript
## Dance of Many — {U}{U} — Enchantment — (drk, rare)
## Oracle: When this enchantment enters, create a token that's a copy of
##         target nontoken creature.
##         When this enchantment leaves the battlefield, exile the token.
##         When the token leaves the battlefield, sacrifice this enchantment.
##         At the beginning of your upkeep, sacrifice this enchantment
##         unless you pay {U}{U}.
##
## Implementation: the token is a real copy — a token built from the chosen
## creature's own definition, so it has that creature's abilities, not just
## its body. The Dance remembers the token's id, and the two leave-triggers
## keep them locked together in both directions.
##
## The upkeep {U}{U} is a real question for the controller's seat (asked
## through their DecisionAgent, hint "pay").
##
## "Target nontoken creature" is a real TARGET of the ETB trigger
## (TriggeredAbility.targeting): the Dance's controller names it as the
## trigger goes on the stack (CR 603.3d) — a human seat is asked the
## moment a player would receive priority, with the original's generic
## prompt (`@TARGET_CREATURE`, `Program/prompts.txt`: "Select target
## creature.") — a token or a creature with shroud is not on the list,
## with no nontoken creature at all the trigger is removed instead, and
## it fizzles if the creature has left by resolution (CR 608.2b): no
## token, and the Dance sits there paying rent for nothing. Either side's
## creatures are legal; the list is ranked biggest first, which is the
## heuristic seat's pick and the human seat's default highlight.


func build() -> CardData:
	return CardData.new("Dance of Many", "{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _make_token,
			"When this enchantment enters, create a token that's a copy of target nontoken creature.",
			_is_self) \
			.targeting(TargetSpec.creature("target nontoken creature", _nontoken),
				_biggest_first, "Select target creature.") \
			.capturing(_entry_stamp)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _exile_token,
			"When this enchantment leaves the battlefield, exile the token.",
			_is_self_leaving)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _die_with_token,
			"When the token leaves the battlefield, sacrifice this enchantment.",
			_is_my_token_leaving)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _pay_the_rent,
			"At the beginning of your upkeep, sacrifice this enchantment unless you pay {U}{U}.",
			_your_upkeep)) \
		.oracle("When this enchantment enters, create a token that's a copy of target nontoken creature.\nWhen this enchantment leaves the battlefield, exile the token.\nWhen the token leaves the battlefield, sacrifice this enchantment.\nAt the beginning of your upkeep, sacrifice this enchantment unless you pay {U}{U}.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _is_self_leaving(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	# The Dance's own memory is already wiped by the time it leaves, so the
	# token id comes from the event's memory SNAPSHOT.
	var parting: Dictionary = event.data.get("memory", {})
	return event.data.get("instance") == source and parting.has("token")


static func _is_my_token_leaving(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if not source.memory.has("token"):
		return false
	var gone: CardInstance = event.data.get("instance")
	return gone != null and gone.id == int(source.memory["token"])


static func _your_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _nontoken(inst: CardInstance) -> bool:
	return not inst.is_token


## The biggest body first, whoever controls it.
static func _biggest_first(game: MtgGame, _source: CardInstance,
		a: TargetRef, b: TargetRef) -> bool:
	var ia := game.find_instance(a.instance_id)
	var ib := game.find_instance(b.instance_id)
	var va := ia.cur_power + ia.cur_toughness
	var vb := ib.cur_power + ib.cur_toughness
	if va != vb:
		return va > vb
	return ia.id < ib.id


## The token is made even if the Dance has already left the battlefield
## (CR 603.6): the ETB resolves on its own. Nothing then links the two —
## the Dance's leave-trigger already resolved with no token to exile, and
## a Dance that is gone cannot be sacrificed — so the token simply stays
## (the card's Gatherer ruling says as much; until 2026-10-03 no token was
## made).
## Only the Dance that is still the object that entered remembers it.
static func _entry_stamp(_game: MtgGame, source: CardInstance,
		_event: GameEvent) -> Dictionary:
	return {"stamp": source.layer_timestamp}


static func _make_token(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var refs: Array = game.current_targets()
	if refs.is_empty():
		return
	var best := game.find_instance(refs[0].instance_id)
	if best == null or best.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := game.current_resolution_controller()
	if pid < 0:
		pid = source.controller_id
	# The copiable values of a face-down creature are a nameless 2/2
	# (CR 707.2, 708.2) — not the card under the mask (2026-10-03).
	var made := game.create_token(pid, game.copiable_data(best))
	if made.is_empty():
		return
	var stamp := int(game.trigger_context(source).get("stamp", source.layer_timestamp))
	if source.zone == Mtg.Zone.BATTLEFIELD and source.layer_timestamp == stamp:
		source.memory["token"] = made[0].id


static func _exile_token(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var parting: Dictionary = event.data.get("memory", {})
	var token := game.find_instance(int(parting.get("token", -1)))
	source.memory.erase("token")
	if token != null and token.zone == Mtg.Zone.BATTLEFIELD:
		game.exile_permanent(token)


static func _die_with_token(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	source.memory.erase("token")
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.sacrifice_permanent(source)


static func _pay_the_rent(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var rent := ManaCost.parse("{U}{U}")
	var pid := source.controller_id
	var can := game.can_afford_cost(pid, rent)
	if can and game.agents[pid].choose_yes_no(game, pid,
			"Pay {U}{U} to keep Dance of Many?", true) and game.try_pay(pid, rent):
		return
	game.sacrifice_permanent(source)
