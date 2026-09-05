extends CardScript
## Stangg — {4}{R}{G} — Legendary Creature — Human Warrior — 3/4 — (leg, rare)
## Oracle: When Stangg enters, create Stangg Twin, a legendary 3/4 red and
##         green Human Warrior creature token. Exile that token when
##         Stangg leaves the battlefield. Sacrifice Stangg when that token
##         leaves the battlefield.
##
## Implementation: an ETB trigger creating the Twin, plus a
## LEAVES_BATTLEFIELD trigger that exiles it — six mana for 6/8 across
## two bodies, undone the moment either half is answered. A Twin that
## leaves takes Stangg with it through the same listener.
##
## Both halves are about THAT TOKEN, not about the name: Stangg remembers
## his own Twin's instance id in card memory, so a Stangg Twin someone
## else made (or a copy of one) neither dies to his leave-trigger nor
## drags him down with it. Stangg's memory is wiped when he leaves the
## battlefield (CR 400.7), so the leave-trigger reads the id back out of
## the LEAVES_BATTLEFIELD event's memory snapshot instead.


func build() -> CardData:
	return CardData.new("Stangg", "{4}{R}{G}", Mtg.CardType.CREATURE) \
		.pt(3, 4) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "warrior"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _summon_twin,
			"When Stangg enters, create Stangg Twin.",
			_is_self)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _settle,
			"Exile Stangg Twin when Stangg leaves the battlefield; sacrifice Stangg "
			+ "when the Twin leaves.",
			_either_half_left)) \
		.oracle("When Stangg enters, create Stangg Twin, a legendary 3/4 red and "
			+ "green Human Warrior creature token. Exile that token when Stangg leaves "
			+ "the battlefield. Sacrifice Stangg when that token leaves the battlefield.")


static func _twin_data() -> CardData:
	return CardData.new("Stangg Twin", "", Mtg.CardType.CREATURE) \
		.with_colors(Mtg.ManaColor.R | Mtg.ManaColor.G) \
		.pt(3, 4) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "warrior"]) \
		.oracle("")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


## The id of the Twin THIS Stangg made, read from his own memory while he
## is on the battlefield and from the parting snapshot once he has left.
static func _twin_id(source: CardInstance, event: GameEvent) -> int:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		return int(source.memory.get("twin", -1))
	var parting: Dictionary = event.data.get("memory", {})
	return int(parting.get("twin", -1))


static func _either_half_left(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var gone: CardInstance = event.data.get("instance")
	if gone == null:
		return false
	return gone == source or gone.id == _twin_id(source, event)


static func _summon_twin(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var made := game.create_token(source.controller_id, _twin_data())
	if not made.is_empty():
		source.memory["twin"] = made[0].id


static func _settle(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var gone: CardInstance = event.data["instance"]
	if gone == source:
		var twin := game.find_instance(_twin_id(source, event))
		if twin != null and twin.zone == Mtg.Zone.BATTLEFIELD:
			game.exile_permanent(twin)
	elif source.zone == Mtg.Zone.BATTLEFIELD:
		game.sacrifice_permanent(source)
