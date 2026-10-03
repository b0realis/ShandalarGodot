extends RefCounted
## Declarative, non-targeted object costs (CR 118, 601.2h, 602.2b).
## A group is {operation, filter, desc, count?, opponent?, zone?, kind?,
## source_filter?, count_is_x?, position?}. Every choice is gathered before
## payment. Disjoint assignment prevents a creature that is also a Swamp
## from paying both Drone sacrifices.
##
## OPERATIONS (Pack 8 widened the vocabulary, 2026-10-03):
##   sacrifice  — a permanent you control (battlefield);
##   tap/untap  — a permanent you (or, `opponent`, they) control;
##   discard    — a card in your hand (`zone` HAND);
##   counter    — put a `kind` counter on a permanent you control;
##   return     — a permanent you control to its OWNER's hand (Quirion
##                Ranger's Forest, Flooded Shoreline's Islands, Infernal
##                Harvest's X Swamps);
##   exile      — a card in `zone`: BATTLEFIELD (a permanent you control),
##                HAND (Cadaverous Bloom) or GRAVEYARD (Haunting Misery);
##   discard_hand  — every card in your hand but the paying spell itself
##                (Lion's Eye Diamond, Kaervek's Spite). No choice; an
##                empty hand pays it;
##   sacrifice_all — every permanent you control passing `filter` (all of
##                them when unset — Kaervek's Spite). No choice; paid as
##                one simultaneous event.
## GROUP KEYS:
##   count       — how many objects (default 1);
##   count_is_x  — the count IS the announced X (CR 107.3, 601.2b: X is
##                 chosen with the announcement; Infernal Harvest, Haunting
##                 Misery, Firestorm). The spell/ability passes its X;
##   position    — "top": the topmost `count` cards of your GRAVEYARD that
##                 pass `filter`, in order. NOT a choice (Alms, Necratog,
##                 Zombie Scavengers, Nature's Kiss, Spinning Darkness), so
##                 nobody is ever asked which;
##   filter      — Callable(card) -> bool; unset = any object;
##   source_filter — Callable(game, card, source) -> bool.
## The builders below make the groups; card scripts should use them rather
## than spell the dictionaries out.

const ALL_OPERATIONS := ["discard_hand", "sacrifice_all"]


# ---------------------------------------------------------------- builders --

## "Sacrifice [count] <desc>".
static func sacrificing(desc: String, filter := Callable(), count := 1) -> Dictionary:
	return {"operation": "sacrifice", "desc": desc, "filter": filter, "count": count}

## "Return [count] <desc> to its owner's hand" (CR 601.2h; the bounced
## permanent goes to its OWNER's hand even when another player owns it).
static func returning(desc: String, filter := Callable(), count := 1) -> Dictionary:
	return {"operation": "return", "desc": desc, "filter": filter, "count": count}

## "Exile [count] <desc>" from [param zone] (Mtg.Zone.BATTLEFIELD, HAND or
## GRAVEYARD), chosen by the payer.
static func exiling(zone: int, desc: String, filter := Callable(), count := 1) -> Dictionary:
	return {"operation": "exile", "zone": zone, "desc": desc, "filter": filter, "count": count}

## "Exile the top [count] <desc> of your graveyard" — positional, not a
## choice ("the top creature card of your graveyard": the topmost card that
## IS a creature card, whatever lies above it).
static func exiling_top(desc := "card", filter := Callable(), count := 1) -> Dictionary:
	return {"operation": "exile", "zone": Mtg.Zone.GRAVEYARD, "desc": desc,
		"filter": filter, "count": count, "position": "top"}

## "Discard [count] <desc>" — chosen by the payer.
static func discarding(desc := "card", filter := Callable(), count := 1) -> Dictionary:
	return {"operation": "discard", "zone": Mtg.Zone.HAND, "desc": desc, "filter": filter, "count": count}

## "Tap [count] untapped <desc> you control".
static func tapping(desc: String, filter := Callable(), count := 1) -> Dictionary:
	return {"operation": "tap", "desc": desc, "filter": filter, "count": count}

## "Discard your hand".
static func discard_hand() -> Dictionary:
	return {"operation": "discard_hand", "zone": Mtg.Zone.HAND, "desc": "your hand", "filter": Callable()}

## "Sacrifice all <desc>" — every permanent you control passing the filter.
static func sacrifice_all(desc := "all permanents you control", filter := Callable()) -> Dictionary:
	return {"operation": "sacrifice_all", "desc": desc, "filter": filter}

## Make [param group]'s count the announced X ("return X Swamps").
static func times_x(group: Dictionary) -> Dictionary:
	group["count_is_x"] = true
	return group


# ----------------------------------------------------------------- queries --

static func is_all(group: Dictionary) -> bool:
	return String(group.get("operation", "")) in ALL_OPERATIONS

static func uses_x(groups: Array) -> bool:
	for group in groups:
		if group.get("count_is_x", false): return true
	return false

static func count_of(group: Dictionary, x := 0) -> int:
	return maxi(0, x) if group.get("count_is_x", false) else int(group.get("count", 1))

static func _passes(group: Dictionary, card: CardInstance) -> bool:
	var filter: Callable = group.get("filter", Callable())
	return not filter.is_valid() or bool(filter.call(card))


static func pools(g: MtgGame, pid: int, groups: Array, source_card: CardInstance = null, x := 0) -> Array:
	var out: Array = []
	for group in groups:
		if is_all(group): continue
		var owner := 1 - pid if group.get("opponent", false) else pid
		var zone: int = group.get("zone", Mtg.Zone.BATTLEFIELD)
		var count := count_of(group, x)
		var candidates: Array[CardInstance] = []
		if group.get("position", "") == "top":
			# The TOPMOST matching cards, top first: an ordered cost with
			# nothing to choose (the top of a graveyard is its LAST card).
			var grave: Array = g.players[owner].graveyard
			for i in range(grave.size() - 1, -1, -1):
				var card: CardInstance = grave[i]
				if card == source_card or not _passes(group, card): continue
				candidates.append(card)
				if candidates.size() >= count: break
		else:
			var source: Array = g.players[owner].battlefield
			if zone == Mtg.Zone.HAND: source = g.players[owner].hand
			elif zone == Mtg.Zone.GRAVEYARD: source = g.players[owner].graveyard
			for card in source:
				if zone != Mtg.Zone.BATTLEFIELD and card == source_card: continue
				if group.has("source_filter") and not group.source_filter.call(g, card, source_card): continue
				if group.operation == "tap" and card.tapped: continue
				if group.operation == "untap" and not card.tapped: continue
				if _passes(group, card): candidates.append(card)
		for unused in count: out.append({"group": group, "cards": candidates.duplicate()})
	return out

static func can_assign(slots: Array, index := 0, used := {}) -> bool:
	if index >= slots.size(): return true
	for card in slots[index].cards:
		if used.has(card.id): continue
		var next := used.duplicate()
		next[card.id] = true
		if can_assign(slots, index + 1, next): return true
	return false

static func refusal(g: MtgGame, pid: int, groups: Array, source: CardInstance = null, x := 0) -> String:
	return "" if can_assign(pools(g, pid, groups, source, x)) else "not enough distinct eligible cards to pay the additional costs"

## The largest X the count-is-X groups of [param groups] can be paid for
## right now, or -1 when no group's count is X (no object bound at all).
## The AI sizes X with it; the engine's own refusal is [method refusal].
static func max_x(g: MtgGame, pid: int, groups: Array, source: CardInstance = null) -> int:
	if not uses_x(groups): return -1
	var x := 0
	while x < 200 and can_assign(pools(g, pid, groups, source, x + 1)):
		x += 1
	return x


static func _prompt(group: Dictionary, done: int, total: int) -> String:
	var operation := String(group.operation)
	var desc := String(group.desc)
	var prompt := "%s %s" % [operation.capitalize(), desc]
	match operation:
		"counter": prompt = "Put a %s counter on %s" % [group.kind, desc]
		"return": prompt = "Return %s to its owner's hand" % desc
		"exile":
			var zone: int = group.get("zone", Mtg.Zone.BATTLEFIELD)
			if zone == Mtg.Zone.HAND: prompt += " from your hand"
			elif zone == Mtg.Zone.GRAVEYARD: prompt += " from your graveyard"
	if total > 1: prompt += " (%d/%d)" % [done + 1, total]
	return prompt


## Gather every choice the groups need. [param replay] is the action record
## a held question re-issues; EMPTY means the payment happens while a
## spell or ability RESOLVES (an "unless you return ..." choice), where the
## resolution pre-flight holds the duel instead and nothing is held here.
static func choose(g: MtgGame, pid: int, source: CardInstance, groups: Array, replay: Dictionary, x := 0) -> Array:
	var slots := pools(g, pid, groups, source, x)
	var chosen: Array = []
	var used := {}
	for index in slots.size():
		var group: Dictionary = slots[index].group
		var offered: Array[CardInstance] = []
		for card in slots[index].cards:
			if used.has(card.id): continue
			var next := used.duplicate()
			next[card.id] = true
			if can_assign(slots, index + 1, next): offered.append(card)
		if offered.is_empty(): return []
		var pick: CardInstance = offered[0]
		if group.get("position", "") != "top":
			var prompt := _prompt(group, index - _first_slot(slots, group), count_of(group, x))
			var question := g._cost_question(pid, source, PlayerChoice.Kind.CARD, prompt)
			question.candidates = offered
			if not replay.is_empty() and g._hold_cost_choice(question, replay): return []
			pick = g._ask_cost_card(pid, source, offered, prompt)
		used[pick.id] = true
		chosen.append({"group": group, "card": pick})
	for group in groups:
		if is_all(group): chosen.append({"group": group, "all": true, "source": source})
	return chosen


## The first slot [param group] owns — its asks are numbered from there.
static func _first_slot(slots: Array, group: Dictionary) -> int:
	for i in slots.size():
		if is_same(slots[i].group, group): return i
	return 0


static func _row(card: CardInstance, operation: String) -> Dictionary:
	return {"id": card.id, "stamp": card.layer_timestamp, "mana_value": card.data.cost.mana_value(),
		"operation": operation, "name": card.data.card_name,
		"types": card.cur_types if card.zone == Mtg.Zone.BATTLEFIELD else card.data.types,
		"power": card.cur_power, "zone": card.zone}


## Pay [param choices] (from [method choose]) through MtgGame's journaled
## helpers. The receipt — one row per object, in payment order — is what
## the spell or ability reads back as `_object_costs` (MtgGame.cost_paid).
static func pay(g: MtgGame, pid: int, choices: Array) -> Array:
	var receipt: Array = []
	var bracket := false
	for choice in choices:
		if choice.has("all"):
			bracket = true
	if bracket: g.begin_simultaneous()
	for choice in choices:
		if choice.has("all"):
			_pay_all(g, pid, choice, receipt)
			continue
		var card: CardInstance = choice.card
		receipt.append(_row(card, String(choice.group.operation)))
		match String(choice.group.operation):
			"sacrifice": g.sacrifice_permanent(card)
			"tap": g.tap_permanent(card)
			"untap": g.untap_permanent(card)
			"discard": g.discard_cards(pid, [card], false)
			"counter": g.add_counters(card, choice.group.kind)
			"return": g.return_to_hand(card)
			"exile":
				match card.zone:
					Mtg.Zone.BATTLEFIELD: g.exile_permanent(card)
					Mtg.Zone.HAND: g.exile_from_hand(card)
					Mtg.Zone.GRAVEYARD: g.exile_from_graveyard(card)
	if bracket: g.end_simultaneous()
	return receipt


static func _pay_all(g: MtgGame, pid: int, choice: Dictionary, receipt: Array) -> void:
	var group: Dictionary = choice.group
	var source: CardInstance = choice.get("source", null)
	match String(group.operation):
		"discard_hand":
			var hand: Array = []
			for card in g.players[pid].hand:
				if card != source: hand.append(card)
			for card in hand: receipt.append(_row(card, "discard"))
			# A COST discard (CR 601.2h): Library of Leng has no say.
			if not hand.is_empty(): g.discard_cards(pid, hand, false)
		"sacrifice_all":
			var bodies: Array = []
			for card in g.players[pid].battlefield:
				if _passes(group, card): bodies.append(card)
			for card in bodies:
				receipt.append(_row(card, "sacrifice"))
			for card in bodies:
				g.sacrifice_permanent(card)
