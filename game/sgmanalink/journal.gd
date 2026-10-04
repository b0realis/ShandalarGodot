class_name SgJournal
extends RefCounted
## Audience-filtered, bounded online history. Never reads the referee's log,
## RNG, private deck lists or hidden card names. Text is derived only from
## allowlisted public events and explicitly audience-authorized information.

const LIMIT := 256
var game: MtgGame
var entries: Array = [[], []]
var _serial: Array[int] = [0, 0]
var _phase := ""
var _life: Array = []
var _finished := false

func _init(referee: MtgGame) -> void:
	game = referee
	game.event_occurred.connect(_event)
	game.information_revealed.connect(_information)
	game.state_changed.connect(observe)
	observe()

func _append(viewer: int, text: String, kind: String, pid := -1) -> void:
	_serial[viewer] += 1
	entries[viewer].append({"serial": _serial[viewer], "turn": game.turn_number,
		"step": int(game.current_step()), "pid": pid, "kind": kind, "text": text.left(512)})
	if entries[viewer].size() > LIMIT: entries[viewer].pop_front()

func _public(text: String, kind: String, pid := -1) -> void:
	for viewer in 2: _append(viewer, text, kind, pid)

## A card's name as [param viewer] may know it, or a hidden stand-in written
## for the middle of a sentence ("Wizard draws a card."); [method _cap] puts
## one at the start of a sentence ("A face-down card dies.").
func _name(card: CardInstance, viewer: int) -> String:
	if card == null: return "an effect"
	if card.face_down: return "a face-down card"
	if card.zone in [Mtg.Zone.BATTLEFIELD, Mtg.Zone.GRAVEYARD, Mtg.Zone.STACK, Mtg.Zone.EXILE, Mtg.Zone.ANTE] \
		or (card.zone == Mtg.Zone.HAND and (card.owner_id == viewer or card.revealed_in_hand or game.players[card.owner_id].hand_revealed)):
		return card.data.card_name
	return "a card"

static func _cap(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)

func _event(event: GameEvent) -> void:
	if game.is_probing(): return
	var data := event.data
	var pid := int(data.get("player", data.get("controller", -1)))
	for viewer in 2:
		var text := ""
		var kind := ""
		var who: String = game.players[pid].player_name if pid in [0, 1] else "Player"
		var card: CardInstance = data.get("instance")
		match event.type:
			Mtg.EventType.LAND_PLAYED:
				text = "%s plays %s." % [who, _name(card, viewer)]
				kind = "land"
			Mtg.EventType.SPELL_CAST:
				text = "%s casts %s." % [who, _name(card, viewer)]
				kind = "cast"
			Mtg.EventType.ABILITY_ACTIVATED:
				text = "%s activates %s." % [who, _name(card, viewer)]
				kind = "ability"
			Mtg.EventType.CARD_DRAWN:
				text = "%s draws %s." % [who, _name(card, viewer)]
				kind = "draw"
			Mtg.EventType.CARD_DISCARDED:
				text = "%s discards %s." % [who, _name(card, viewer)]
				kind = "discard"
			Mtg.EventType.ENTERS_BATTLEFIELD:
				text = "%s enters the battlefield." % _cap(_name(card, viewer))
				kind = "enter"
			Mtg.EventType.DIES:
				text = "%s dies." % _cap(_name(card, viewer))
				kind = "dies"
			Mtg.EventType.TAPPED_FOR_MANA:
				text = "%s taps %s for mana." % [who, _name(card, viewer)]
				kind = "mana"
			Mtg.EventType.BLOCKED:
				text = "%s blocks %s." % [_cap(_name(data.blocker, viewer)), _name(data.attacker, viewer)]
				kind = "block"
			Mtg.EventType.DECLARED_ATTACKERS:
				text = "%s attacks with %d creature(s)." % [game.players[game.active_player].player_name, data.attackers.size()]
				kind = "attack"
			Mtg.EventType.DAMAGE_DEALT:
				var target: String = game.players[int(data.to_player)].player_name if data.has("to_player") else _name(data.get("to_instance"), viewer)
				text = "%s deals %d damage to %s." % [_cap(_name(data.get("source"), viewer)), int(data.amount), target]
				kind = "damage"
		if not text.is_empty(): _append(viewer, text, kind, pid)

func _information(viewer: int, title: String, names: Array) -> void:
	if game.is_probing(): return
	for seat in 2:
		if viewer not in [-1, seat]: continue
		if names.is_empty(): _append(seat, title.left(220) + ": no cards.", "reveal")
		for name in names: _append(seat, title.left(220) + ": " + String(name), "reveal")

func observe() -> void:
	if game.is_probing() or game.players.size() != 2: return
	var phase := "%d/%d/%d" % [game.turn_number, game.current_step(), game.active_player]
	if phase != _phase:
		_phase = phase
		_public("Turn %d — %s — %s." % [game.turn_number, game.players[game.active_player].player_name,
			String(Mtg.Step.keys()[game.current_step()]).replace("_", " ").capitalize()], "phase", game.active_player)
	var life := [game.players[0].life, game.players[1].life]
	if not _life.is_empty():
		for pid in 2:
			if life[pid] != _life[pid]: _public("%s: %d life (%+d)." % [game.players[pid].player_name, life[pid], life[pid] - _life[pid]], "life", pid)
	_life = life
	if game.game_over and not _finished:
		_finished = true
		_public("Duel drawn." if game.is_draw else "%s wins the duel." % game.players[game.winner].player_name, "result")
