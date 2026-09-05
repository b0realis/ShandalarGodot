extends CardScript
## Wall of Tombstones — {1}{B} — Creature — Wall — 0/1 — (leg, uncommon)
## Oracle: Defender (This creature can't attack.)
##         At the beginning of your upkeep, change this creature's base
##         toughness to 1 plus the number of creature cards in your
##         graveyard. (This effect lasts indefinitely.)
##
## Implementation: the printed card is a TRIGGER, not a characteristic-
## defining ability — the number is counted once, when the upkeep trigger
## resolves, and the resulting base toughness lasts indefinitely (CR
## 603.1 / 613.4b). So the upkeep trigger records the count in card memory
## and a base-P/T static replays the recorded value on every pass; a
## graveyard that grows or shrinks later in the turn (a fetched Regrowth,
## Tormod's Crypt) does not move the Wall until its next upkeep. Before
## the first upkeep the Wall is its printed 0/1, and the recorded value
## dies with the permanent (memory is wiped by the zone change, CR 400.7).


func build() -> CardData:
	return CardData.new("Wall of Tombstones", "{1}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _count_the_dead,
			"At the beginning of your upkeep, change Wall of Tombstones's base "
			+ "toughness to 1 plus the number of creature cards in your graveyard.",
			_your_upkeep)) \
		.static_ability(StaticAbility.new(
			_apply,
			"Wall of Tombstones's base toughness is the value recorded at its "
			+ "controller's last upkeep.").setting_base_pt()) \
		.oracle("Defender (This creature can't attack.)\nAt the beginning of your "
			+ "upkeep, change this creature's base toughness to 1 plus the number of "
			+ "creature cards in your graveyard. (This effect lasts indefinitely.)")


static func _your_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _count_the_dead(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var corpses := 0
	for inst in game.players[source.controller_id].graveyard:
		if inst.data.is_creature():
			corpses += 1
	source.memory["toughness"] = 1 + corpses
	game.recalculate()


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	source.cur_toughness = int(source.memory.get("toughness", source.data.toughness))
