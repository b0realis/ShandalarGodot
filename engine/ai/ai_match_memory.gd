class_name AiMatchMemory
extends RefCounted
## WHAT ONE SEAT SAW — the only thing an AI is allowed to sideboard on.
##
## The rule this class exists to enforce is a fairness rule, not a
## convenience: the AI must NOT know the opponent's decklist. Reading it
## would be cheating, the original does not cheat here (the 1997 opponent
## plays a fixed rogue deck and adapts to nothing), and a sideboard plan
## built from the list is not sideboarding, it is a lookup. So this holds
## the paper-Magic signal instead — every card the opponent CAST, PLAYED
## or put onto the battlefield in the duels already played, plus how much
## damage each colour has dealt to us — and the sideboarder
## ([AiSideboard]) may read nothing else.
##
## USE. One memory per AI seat, alive for the whole match:
## [codeblock]
## var memory := AiMatchMemory.new(1)
## memory.watch(game)          # before the duel starts
## ...                          # the duel plays out
## memory.end_duel()            # folds this duel's tally into the match's
## [/codeblock]
## [method watch] connects to [signal MtgGame.event_occurred], which is the
## same stream the duel screen animates from, so nothing here reaches into
## a hidden zone: an event about a card in a hand or a library is never
## dispatched in the first place.
##
## COPIES ARE COUNTED PER DUEL AND KEPT AT THE MAXIMUM, never summed.
## Four Lightning Bolts across three duels is four Bolts in the opponent's
## deck, not twelve — the same estimate a human makes at the table.
##
## Pure engine: RefCounted, headless, no randomness of its own.

## The seat this memory belongs to. Everything recorded is about the OTHER
## seat, except [member damage_by_color], which is damage taken by this one.
var pid: int

## Opponent card name -> the most copies seen in any single duel.
var seen: Dictionary = {}

## Mtg.ManaColor -> damage that colour has dealt to [member pid] across the
## match. A [Circle of Protection] is worth boarding in for the colour that
## actually hurt, which is a different question from which colours the
## opponent's cards are.
var damage_by_color: Dictionary = {}

## How many duels have been folded in. 0 means nothing has been seen yet,
## which is what makes duel 1 of a match sideboard-free.
var duels := 0

## This duel's tally, folded into [member seen] by [method end_duel].
var _this_duel: Dictionary = {}

## Instance ids already counted THIS duel — see [method _note]. Instance
## ids restart at 1 in every new [MtgGame], so this is cleared with the
## duel's tally or duel 2 would silently ignore its first few permanents.
var _seen_ids: Dictionary = {}


func _init(p_pid: int) -> void:
	pid = p_pid


## Start recording [param game]. Safe to call once per duel of the match;
## the connection dies with the game object.
func watch(game: MtgGame) -> void:
	if not game.event_occurred.is_connected(_on_event):
		game.event_occurred.connect(_on_event)


## Fold this duel's tally into the match's and start a fresh one. Called
## when a duel ends, before the sideboard step.
func end_duel() -> void:
	duels += 1
	for card_name in _this_duel:
		seen[card_name] = maxi(int(seen.get(card_name, 0)),
			int(_this_duel[card_name]))
	_this_duel.clear()
	_seen_ids.clear()


## How many copies of [param card_name] the opponent has been seen with.
func copies_seen(card_name: String) -> int:
	return int(seen.get(card_name, 0))


## Damage [param color] has dealt to this seat across the match.
func damage_from(color: int) -> int:
	return int(damage_by_color.get(color, 0))


# ------------------------------------------------------------ recording --

func _on_event(event: GameEvent) -> void:
	match event.type:
		# WHAT COUNTS AS "SEEN". A cast spell and a played land are seen by
		# everyone at the table (CR 601.2a announces on the stack). So is a
		# permanent that arrives without being cast — an Animate Dead
		# target, a Sleight of Mind'd Illusionary Mask — which is why
		# ENTERS_BATTLEFIELD is here too and why it is deduplicated against
		# the cast tally rather than added to it.
		Mtg.EventType.SPELL_CAST, Mtg.EventType.LAND_PLAYED, \
		Mtg.EventType.ENTERS_BATTLEFIELD:
			if int(event.data.get("controller", -1)) == pid:
				return
			var inst: CardInstance = event.data.get("instance")
			if inst == null or inst.is_token:
				# A token is not a card in anybody's deck, so boarding
				# against one would be boarding against a spell we already
				# counted when it was cast.
				return
			_note(inst)
		Mtg.EventType.DAMAGE_DEALT:
			if int(event.data.get("to_player", -1)) != pid:
				return
			var source: CardInstance = event.data.get("source")
			if source == null:
				return
			var amount := int(event.data.get("amount", 0))
			if amount <= 0:
				return
			# LIVE colours (CONTRIBUTING.md rule 5): a Sleight of Mind'd source
			# deals damage as the colour it IS, not the one it was printed.
			for color in Mtg.COLOR_NAMES:
				if source.cur_colors & color:
					damage_by_color[color] = damage_from(color) + amount


## Count one sighting. Each INSTANCE is counted once per duel however many
## times it is seen — a creature that is cast, dies, is reanimated and
## enters again is one card, not three.
func _note(inst: CardInstance) -> void:
	var card_name := inst.data.card_name
	if _seen_ids.has(inst.id):
		return
	_seen_ids[inst.id] = true
	_this_duel[card_name] = int(_this_duel.get(card_name, 0)) + 1
