class_name CumulativeUpkeep
extends RefCounted
## CR 702.24: one age counter, then one indivisible payment multiplied by
## ALL age counters. Each instance is its own trigger; no partial payment.
## Restricted upkeep mana is visible to both planning and final payment.

const USAGE := ["cumulative_upkeep"]

static func attach(card: CardData, cost := "", life := 0, sacrifice_type := "") -> CardData:
	return card.triggered(ability(cost, life, sacrifice_type))

static func ability(cost := "", life := 0, sacrifice_type := "") -> TriggeredAbility:
	return TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
		_resolve.bind(cost, life, sacrifice_type),
		"Cumulative upkeep " + (cost if cost != "" else "— ") +
		("Pay %d life" % life if life > 0 else "") +
		("Sacrifice a " + sacrifice_type if sacrifice_type != "" else ""),
		_your_upkeep).capturing(_capture)

# ------------------------------------------------- custom (non-mana) costs --
# Pack 8 (2026-10-03): "Cumulative upkeep—Draw a card" (Psychic Vortex),
# "Cumulative upkeep—Put a -1/-1 counter on this creature" (Aboroth). A
# PAYMENT is a Dictionary:
#   "text":    the cost as printed, for the ability text and the prompt;
#   "kind":    "draw" | "self_counter" | "custom";
#   "counter": the counter kind ("self_counter");
#   "can_pay": Callable(game, source, pid, ages) -> bool   ("custom"; unset = always);
#   "pay":     Callable(game, source, pid, ages) -> void   ("custom");
#   "hint":    Callable(game, source, pid, ages) -> bool   (optional — the
#              agent's default answer; the built-in kinds bring their own,
#              read from public state only).
# The payment is made ages times over as ONE indivisible payment (CR
# 702.24a); declined or unpayable, the permanent is sacrificed after the
# CUMULATIVE_UPKEEP_UNPAID event — the same as every other upkeep here.

## Attach a custom cumulative upkeep (see the block above).
static func attach_custom(card: CardData, payment: Dictionary) -> CardData:
	return card.triggered(custom_ability(payment))

static func custom_ability(payment: Dictionary) -> TriggeredAbility:
	return TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
		_resolve_custom.bind(payment),
		"Cumulative upkeep—" + String(payment.get("text", "")),
		_your_upkeep).capturing(_capture)

## "Cumulative upkeep—Draw a card" (Psychic Vortex).
static func draw_payment() -> Dictionary:
	return {"kind": "draw", "text": "Draw a card"}

static func attach_draw(card: CardData) -> CardData:
	return attach_custom(card, draw_payment())

## "Cumulative upkeep—Put a <kind> counter on this permanent" (Aboroth).
static func self_counter_payment(kind: String) -> Dictionary:
	return {"kind": "self_counter", "counter": kind,
		"text": "Put a %s counter on this permanent" % kind}

static func attach_self_counter(card: CardData, kind: String) -> CardData:
	return attach_custom(card, self_counter_payment(kind))

## Can [param pid] pay [param payment] for [param ages] age counters?
static func payment_possible(g: MtgGame, source: CardInstance, pid: int, ages: int,
		payment: Dictionary) -> bool:
	match String(payment.get("kind", "custom")):
		"draw":
			return true   # drawing from an empty library is a draw (it loses later)
		"self_counter":
			# A phased-out permanent can't be given counters (CR 702.26b).
			return g.is_present(source)
	var can: Callable = payment.get("can_pay", Callable())
	return not can.is_valid() or bool(can.call(g, source, pid, ages))

## The default answer to "pay it?" — what a seat reading only PUBLIC state
## should say: draw while the library stays safe; put P/T counters while
## the permanent survives them; a custom payment's own hint, else yes.
static func payment_hint(g: MtgGame, source: CardInstance, pid: int, ages: int,
		payment: Dictionary) -> bool:
	match String(payment.get("kind", "custom")):
		"draw":
			return g.players[pid].library.size() > ages + 2
		"self_counter":
			var delta := ContinuousEffects.parse_pt_counter(String(payment.get("counter", "")))
			if not source.is_creature() or delta.y >= 0:
				return true
			return source.cur_toughness + delta.y * ages > source.damage
	var hint: Callable = payment.get("hint", Callable())
	return not hint.is_valid() or bool(hint.call(g, source, pid, ages))

static func _pay_custom(g: MtgGame, source: CardInstance, pid: int, ages: int,
		payment: Dictionary) -> void:
	match String(payment.get("kind", "custom")):
		"draw":
			g.draw_cards(pid, ages)
		"self_counter":
			g.add_counters(source, String(payment.get("counter", "")), ages)
		_:
			var pay: Callable = payment.get("pay", Callable())
			if pay.is_valid(): pay.call(g, source, pid, ages)

static func _resolve_custom(g: MtgGame, source: CardInstance, _event: GameEvent,
		payment: Dictionary) -> void:
	var context := g.trigger_context(source)
	if not _still_here(g, source, context):
		return
	var pid := int(context.get("controller", source.controller_id))
	g.add_counters(source, "age")
	var ages := int(source.counters.get("age", 0))
	var affordable := payment_possible(g, source, pid, ages, payment)
	var hint := affordable and payment_hint(g, source, pid, ages, payment)
	var prompt := "%s: pay cumulative upkeep (%d age counters) — %s x%d?" % [
		source.data.card_name, ages, String(payment.get("text", "")), ages]
	if not affordable or not g.agents[pid].choose_yes_no(g, pid, prompt, hint):
		_unpaid(g, source, pid, ages)
		return
	_pay_custom(g, source, pid, ages, payment)


## The upkeep was NOT paid: say so (Heart of Bogardan's "when a player
## doesn't pay"), then sacrifice — CR 702.24a. The event goes first so the
## permanent hears it while it is still on the battlefield.
static func _unpaid(g: MtgGame, source: CardInstance, pid: int, ages: int) -> void:
	g.dispatch_event(Mtg.EventType.CUMULATIVE_UPKEEP_UNPAID, {"instance": source,
		"controller": source.controller_id, "player": pid, "ages": ages}, source)
	if source.controller_id == pid:
		g.sacrifice_permanent(source)


static func _your_upkeep(_g: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data.get("player", -1)) == source.controller_id

static func _capture(_g: MtgGame, source: CardInstance, _event: GameEvent) -> Dictionary:
	return {"timestamp": source.layer_timestamp, "controller": source.controller_id}

## CR 702.24a's INTERVENING IF, rechecked on resolution (CR 603.4): "if
## this permanent is on the battlefield" — the very object that triggered
## (CR 400.7), and PHASED IN: a phased-out permanent is treated as though
## it doesn't exist (CR 702.26b), so a Psychic Vortex or Heart of Bogardan
## that phased out with its upkeep on the stack does nothing at all — no
## age counter, no payment, no "wasn't paid" event, no sacrifice.
static func _still_here(g: MtgGame, source: CardInstance, context: Dictionary) -> bool:
	return g.is_present(source) and source.layer_timestamp == int(context.get("timestamp", -1))

static func _resolve(g: MtgGame, source: CardInstance, _event: GameEvent,
		cost_text: String, life: int, sacrifice_type: String) -> void:
	var context := g.trigger_context(source)
	if not _still_here(g, source, context):
		return
	var pid := int(context.get("controller", source.controller_id))
	g.add_counters(source, "age")
	var ages := int(source.counters.get("age", 0))
	var cost := ManaCost.parse(cost_text.repeat(ages))
	var victims: Array[CardInstance] = []
	if sacrifice_type != "":
		for inst in g.players[pid].battlefield:
			if (sacrifice_type == "land" and inst.is_land()) or inst.has_subtype(sacrifice_type):
				victims.append(inst)
	var affordable := g.players[pid].life >= life * ages and g.can_afford_cost(pid, cost, USAGE)
	if sacrifice_type != "" and victims.size() < ages:
		affordable = false
	var hint := g.agents[pid].cumulative_upkeep_hint(g, pid, source, cost, life * ages,
		ages if sacrifice_type != "" else 0)
	var prompt := "%s: pay cumulative upkeep (%d age counters)%s%s%s?" % [
		source.data.card_name, ages, " " + cost.text if cost.text != "" else "",
		" and %d life" % (life * ages) if life > 0 else "",
		" and sacrifice %d %s(s)" % [ages, sacrifice_type] if sacrifice_type != "" else ""]
	if not affordable or not g.agents[pid].choose_yes_no(g, pid, prompt, hint):
		_unpaid(g, source, pid, ages)
		return
	var selected: Array[CardInstance] = []
	if sacrifice_type != "":
		for i in ages:
			var pick := g.agents[pid].choose_card(g, pid, victims,
				"%s: sacrifice %s %d of %d for cumulative upkeep" % [source.data.card_name, sacrifice_type, i + 1, ages])
			# Never optional: the offer was already accepted, so a declined or
			# stale answer takes the first body exactly as a cost's sacrifice
			# does (MtgGame._ask_cost_card, CR 601.2h). Falling out of the
			# resolution here left the age counter on, nothing paid and the
			# permanent alive — the third outcome CR 702.24a does not have.
			if pick == null or not victims.has(pick):
				pick = victims[0]
			victims.erase(pick)
			selected.append(pick)
	if not g.try_pay(pid, cost, USAGE):
		_unpaid(g, source, pid, ages)
		return
	g.begin_simultaneous()
	if life > 0:
		g.adjust_life(pid, -life * ages)
	for inst in selected:
		g.sacrifice_permanent(inst)
	g.end_simultaneous()
