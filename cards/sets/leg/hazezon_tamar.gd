extends CardScript
## Hazezon Tamar — {4}{R}{G}{W} — Legendary Creature — Human Warrior — 2/4 — (leg, rare)
## Oracle: When Hazezon enters, create X 1/1 Sand Warrior creature tokens
##         that are red, green, and white at the beginning of your next
##         upkeep, where X is the number of lands you control at that time.
##         When Hazezon leaves the battlefield, exile all Sand Warriors.
##
## Implementation: the arrival creates a DELAYED triggered ability (CR
## 603.7a — MtgGame.schedule_delayed_trigger): at his controller's next
## upkeep the count is taken (lands "at that time", as printed) and the
## Sand Warriors arrive. The leave-trigger exiles every Sand Warrior on
## the board, whoever controls them.
##
## The delayed trigger lives on the GAME, not on Hazezon, so it survives
## him leaving by any door — sacrificed with it pending, so his
## leave-trigger finds no Sand Warriors to exile (the card's signature
## line), but equally EXILED or BOUNCED in response. "Your next upkeep"
## is fixed when the trigger is created (CR 603.7d): the controller is
## bound into it, and a Hazezon stolen before that upkeep still pays out
## to the player who cast him.


static func _sand_warrior() -> CardData:
	# A token has NO mana cost (CR 111.4), so its mana value is 0 — the
	# colours are declared instead (docs/audit-vs-s30.md, the same fix the
	# other five tokens in the pool took). Great Defender, Subdue, Kry
	# Shield and Juxtapose all read that number.
	return CardData.new("Sand Warrior", "", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_colors(Mtg.ManaColor.R | Mtg.ManaColor.G | Mtg.ManaColor.W) \
		.with_subtypes(["sand", "warrior"]) \
		.oracle("")


func build() -> CardData:
	return CardData.new("Hazezon Tamar", "{4}{R}{G}{W}", Mtg.CardType.CREATURE) \
		.pt(2, 4) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "warrior"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _arm_the_sands,
			"When Hazezon enters, create X 1/1 Sand Warrior tokens at the beginning of your next upkeep.",
			_is_self)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _scatter_the_sands,
			"When Hazezon leaves the battlefield, exile all Sand Warriors.",
			_is_self)) \
		.oracle("When Hazezon enters, create X 1/1 Sand Warrior creature tokens that are red, green, and white at the beginning of your next upkeep, where X is the number of lands you control at that time.\nWhen Hazezon leaves the battlefield, exile all Sand Warriors.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _upkeep_of(_game: MtgGame, _source: CardInstance, event: GameEvent,
		controller: int) -> bool:
	return int(event.data["player"]) == controller


static func _arm_the_sands(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	# "Your next upkeep" is fixed when the delayed trigger is created (CR
	# 603.7d): the controller is bound into both callables.
	var controller := source.controller_id
	game.schedule_delayed_trigger(TriggeredAbility.new(
		Mtg.EventType.UPKEEP_START, _raise_the_sands.bind(controller),
		"At the beginning of your next upkeep, create X 1/1 red, green and white Sand Warrior tokens, where X is the number of lands you control.",
		_upkeep_of.bind(controller)), controller, source)


static func _raise_the_sands(game: MtgGame, _source: CardInstance, _event: GameEvent,
		controller: int) -> void:
	var lands := 0
	for inst in game.players[controller].battlefield:
		if inst.is_land():
			lands += 1
	if lands <= 0:
		return
	game.create_token(controller, _sand_warrior(), lands)


static func _scatter_the_sands(game: MtgGame, _source: CardInstance,
		_event: GameEvent) -> void:
	for inst in game.all_battlefield():
		if inst.has_subtype("sand"):
			game.exile_permanent(inst)
