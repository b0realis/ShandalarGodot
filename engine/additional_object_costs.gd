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
## Pack 9 (E7, 2026-10-06) added three more:
##   random_discard — a card in your hand AT RANDOM (Sonic Burst; Flowstone
##                Flood's buyback). Nobody chooses: the card is rolled on
##                the game's seeded RNG as the cost is PAID (CR 601.2h),
##                from the hand as it stands after every chosen object has
##                gone, never the paying spell itself. It still reserves a
##                card in the disjoint check, so "discard a card and
##                discard a card at random" needs two;
##   library_top — a card from your hand, chosen, put on top of your
##                library (Penance, Hidden Retreat);
##   remove_counter — a permanent you control with at least `amount`
##                counters of `kind`, chosen, loses `amount` of them
##                (Spike Rogue's "remove a +1/+1 counter from a creature
##                you control"). Each slot is a DIFFERENT permanent. Paid
##                without a state-based check: a 0/0 dies once the ability
##                is on the stack, not halfway through its own cost.
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
##   source_filter — Callable(game, card, source) -> bool;
##   kind, amount — remove_counter's counter kind and how many come off
##                 each chosen permanent (default 1).
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

## "Discard [count] card(s) at random" (Pack 9 E7) — rolled at payment on
## the game's RNG, never asked (see the header).
static func discarding_at_random(count := 1, desc := "card") -> Dictionary:
	return {"operation": "random_discard", "zone": Mtg.Zone.HAND, "desc": desc,
		"filter": Callable(), "count": count}

## "Put [count] <desc> from your hand on top of your library" (Pack 9 E7)
## — chosen by the payer.
static func putting_on_top(desc := "card", filter := Callable(), count := 1) -> Dictionary:
	return {"operation": "library_top", "zone": Mtg.Zone.HAND, "desc": desc,
		"filter": filter, "count": count}

## "Remove [amount] <kind> counter(s) from [count] <desc>" (Pack 9 E7) — a
## permanent you control passing [param filter] that carries the counters,
## chosen by the payer ("remove a +1/+1 counter from a creature you
## control" — Spike Rogue). The source itself qualifies when it passes.
static func removing_counter(kind: String, desc: String, filter := Callable(),
		count := 1, amount := 1) -> Dictionary:
	return {"operation": "remove_counter", "kind": kind, "amount": maxi(1, amount),
		"desc": desc, "filter": filter, "count": count}


# ----------------------------------------------------------------- queries --

static func is_all(group: Dictionary) -> bool:
	return String(group.get("operation", "")) in ALL_OPERATIONS

## Is [param group] paid by a ROLL rather than a choice (Pack 9 E7)?
static func is_random(group: Dictionary) -> bool:
	return String(group.get("operation", "")) == "random_discard"

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
				if group.operation == "remove_counter" and (card.phased_out
						or int(card.counters.get(String(group.kind), 0)) < int(group.get("amount", 1))):
					continue
				if _passes(group, card): candidates.append(card)
		for unused in count: out.append({"group": group, "cards": candidates.duplicate()})
	return out

## Can every slot from [param index] on take a DIFFERENT card, none of them
## in [param used] (card id -> true)? A bipartite matching by augmenting
## paths — polynomial in slots × candidates. (Campaign 2026-10, w7-1: this
## was an ordering search that walked every permutation before it could
## say no, so Firestorm's "discard X cards" with ten cards in hand froze
## the host for seconds on every view, X window and AI turn.)
static func can_assign(slots: Array, index := 0, used := {}) -> bool:
	if index >= slots.size(): return true
	var order := range(index, slots.size())
	# Pigeonhole first: more slots than distinct free candidates never fit
	# (an X far above the hand is refused without a search).
	var free := {}
	for i in order:
		for card in slots[i].cards:
			if not used.has(card.id): free[card.id] = true
	if order.size() > free.size(): return false
	var owner := {}
	for i in order:
		if not _augment(slots, i, used, owner, {}): return false
	return true


## Give slot [param i] a card, re-seating earlier slots along an augmenting
## path when every card it could take is held ([param owner]: card id ->
## the slot holding it, updated in place). False when no path exists: then
## no assignment covers the matched slots and this one together, and
## [param owner] is unchanged.
static func _augment(slots: Array, i: int, used: Dictionary, owner: Dictionary, seen: Dictionary) -> bool:
	var cards: Array = slots[i].cards
	for card in cards:
		if not used.has(card.id) and not owner.has(card.id):
			owner[card.id] = i
			return true
	for card in cards:
		if used.has(card.id) or seen.has(card.id): continue
		seen[card.id] = true
		if _augment(slots, int(owner[card.id]), used, owner, seen):
			owner[card.id] = i
			return true
	return false

## The candidates of slot [param index] (none in [param used]) that leave
## every LATER slot payable — what [method choose] offers, in the slot's
## own order. The same set as asking [method can_assign] for each one, from
## ONE matching of the later slots: a card no later slot holds leaves it
## intact; a held one is offered when the slot holding it can be re-seated
## without it (CR 601.2h's distinct objects; campaign 2026-10, w7-1).
static func extendable(slots: Array, index: int, used := {}) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	if index >= slots.size(): return out
	var owner := {}
	for i in range(index + 1, slots.size()):
		if not _augment(slots, i, used, owner, {}): return out
	for card: CardInstance in slots[index].cards:
		if used.has(card.id): continue
		if not owner.has(card.id):
			out.append(card)
			continue
		var without := used.duplicate()
		without[card.id] = true
		var trial := owner.duplicate()
		trial.erase(card.id)
		if _augment(slots, int(owner[card.id]), without, trial, {}): out.append(card)
	return out

static func refusal(g: MtgGame, pid: int, groups: Array, source: CardInstance = null, x := 0) -> String:
	return "" if can_assign(pools(g, pid, groups, source, x)) else "not enough distinct eligible cards to pay the additional costs"

## The largest X the count-is-X groups of [param groups] can be paid for
## right now, or -1 when no group's count is X (no object bound at all);
## 0 when even the fixed groups cannot be paid. The AI sizes X with it; the
## engine's own refusal is [method refusal].
## ONE matching (campaign 2026-10, w7-1): the fixed slots first, then one
## more slot per X group a round, each by an augmenting path, until a round
## fails — a failed slot means no assignment covers the slots so far, so X
## rounds was the bound (the same answer as asking X = 1, 2, … in turn).
static func max_x(g: MtgGame, pid: int, groups: Array, source: CardInstance = null) -> int:
	if not uses_x(groups): return -1
	for group in groups:
		if group.get("count_is_x", false) and String(group.get("position", "")) == "top":
			return _max_x_stepwise(g, pid, groups, source)
	var slots := pools(g, pid, groups, source, 0)
	var owner := {}
	for i in slots.size():
		if not _augment(slots, i, {}, owner, {}): return 0
	# One slot of each X group: a non-positional group's candidates do not
	# depend on X, so every round reuses it.
	var x_slots: Array = []
	for slot in pools(g, pid, groups, source, 1):
		if slot.group.get("count_is_x", false): x_slots.append(slot)
	var x := 0
	while x < 200:
		for slot in x_slots:
			slots.append(slot)
			if not _augment(slots, slots.size() - 1, {}, owner, {}): return x
		x += 1
	return x


## [method max_x] asking X = 1, 2, … in turn — for a POSITIONAL X group
## ("the top X cards"), whose candidates are the topmost X and so change
## with X. Each ask is one polynomial [method can_assign].
static func _max_x_stepwise(g: MtgGame, pid: int, groups: Array, source: CardInstance) -> int:
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
		"library_top": prompt = "Put a %s from your hand on top of your library" % desc
		"remove_counter":
			var amount := int(group.get("amount", 1))
			prompt = "Remove %s %s counter%s from a %s" % ["a" if amount == 1 else str(amount),
				group.kind, "" if amount == 1 else "s", desc]
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
	# The ROLLED slots go last, so every choice before them is checked
	# against the room they need (Pack 9 E7).
	var slots := _random_last(pools(g, pid, groups, source, x))
	var chosen: Array = []
	var used := {}
	for index in slots.size():
		var group: Dictionary = slots[index].group
		if is_random(group):
			# Nobody chooses: the card is rolled as the cost is paid.
			chosen.append({"group": group, "random": true, "source": source})
			continue
		var offered := extendable(slots, index, used)
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


## [param slots] with every rolled ([method is_random]) slot moved to the
## end, order otherwise kept.
static func _random_last(slots: Array) -> Array:
	var chosen: Array = []
	var rolled: Array = []
	for slot in slots:
		if is_random(slot.group): rolled.append(slot)
		else: chosen.append(slot)
	return chosen + rolled


## The first slot [param group] owns — its asks are numbered from there.
static func _first_slot(slots: Array, group: Dictionary) -> int:
	for i in slots.size():
		if is_same(slots[i].group, group): return i
	return 0


static func _row(card: CardInstance, operation: String) -> Dictionary:
	return {"id": card.id, "stamp": card.layer_timestamp, "mana_value": card.data.cost.mana_value(),
		"operation": operation, "name": card.data.card_name,
		"types": card.cur_types if card.zone == Mtg.Zone.BATTLEFIELD else card.data.types,
		"power": card.cur_power, "toughness": card.cur_toughness, "zone": card.zone}


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
	var counters_moved := false
	for choice in choices:
		if choice.has("all"):
			_pay_all(g, pid, choice, receipt)
			continue
		if choice.has("random"):
			continue   # rolled below, once every chosen object has gone
		var card: CardInstance = choice.card
		if String(choice.group.operation) == "library_top":
			# Hand to library: hidden zone to hidden zone. The receipt rides
			# the stack item, so it names nothing (docs/fair-play.md).
			receipt.append({"operation": "library_top"})
		else:
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
			"library_top": g.put_from_hand_on_top_of_library(card)
			"remove_counter":
				_pay_counters(g, card, choice.group, receipt[-1])
				counters_moved = true
	for choice in choices:
		if choice.has("random"):
			_pay_random(g, pid, choice, receipt)
	if bracket: g.end_simultaneous()
	# The characteristics the counters fed, recomputed once the whole cost
	# is paid — and NO state-based check here: that is the enclosing
	# action's, as for the source's own counter cost (MtgGame
	# ._counter_removal_event).
	if counters_moved: g.recalculate()
	return receipt


## Take [param group]'s `amount` counters of `kind` off [param card] as a
## COST (Pack 9 E7): journaled, logged, the COUNTERS_REMOVED event raised,
## and nothing else — see [method pay].
static func _pay_counters(g: MtgGame, card: CardInstance, group: Dictionary, row: Dictionary) -> void:
	var kind := String(group.kind)
	var had := int(card.counters.get(kind, 0))
	var removed := mini(int(group.get("amount", 1)), had)
	if removed <= 0:
		return
	g._rec(card, &"counters")
	if had - removed > 0:
		card.counters[kind] = had - removed
	else:
		card.counters.erase(kind)
	row["counter_kind"] = kind
	row["counters_removed"] = removed
	g.log_line("%s loses %d %s counter(s) (now %d)" % [card.data.card_name, removed, kind, had - removed])
	g._counter_removal_event(card, kind, removed)


## Roll and discard one card for a random_discard slot (Pack 9 E7): from
## the payer's hand as it is NOW — every chosen object already gone —
## leaving out the paying spell itself, on the game's seeded RNG (CR
## 601.2h; a COST discard, so Library of Leng has no say). The check
## before payment reserved the card, so the hand is never short here.
static func _pay_random(g: MtgGame, pid: int, choice: Dictionary, receipt: Array) -> void:
	var group: Dictionary = choice.group
	var source: CardInstance = choice.get("source", null)
	var hand: Array[CardInstance] = []
	for card in g.players[pid].hand:
		if card != source and _passes(group, card):
			hand.append(card)
	if hand.is_empty():
		return
	var card: CardInstance = hand[g.rng.randi_range(0, hand.size() - 1)]
	var row := _row(card, "discard")
	row["random"] = true
	receipt.append(row)
	g.discard_cards(pid, [card], false)


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
