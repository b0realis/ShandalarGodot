extends RefCounted
## THE OWN GOAL (campaign 2026-11-26, bugs1 1-4, 6, 7): the casts and the
## upkeep answers that lose the pilot its own game or its own board, read
## off the card's printed text and the public board — the pilot's own
## hand, both battlefields, both graveyards' and libraries' SIZES. Nothing
## hidden is read, and no card is named: each reading is a printed shape.
##
##  * THE LIBRARY FOR THE GRAVEYARD ("Exile all cards from your library.
##    Then shuffle your graveyard into your library." — Paradigm Shift):
##    cast only when the graveyard is the bigger pile and a library worth
##    having ([constant SHIFT_FLOOR]), or the library is about to run out.
##  * THE DRAW FROM THE GRAVEYARD, OR THE GAME ("If you would draw a card,
##    return a card from your graveyard to your hand instead. If you can't,
##    you lose the game." — Forbidden Crypt): the graveyard is the clock,
##    so it needs [constant CRYPT_FLOOR] cards or more cards than the
##    library it replaces.
##  * THE UPKEEP THAT EATS THE LIBRARY ("When a player doesn't pay this
##    enchantment's cumulative upkeep, that player exiles all cards from
##    their library." — Thought Lash): never cast; on the table, paid
##    whenever it can be, because the price is always less than the whole
##    library.
##  * THE PEACE THAT STOPS OUR OWN ATTACK ("Creatures can't attack." —
##    Peacekeeper): cast, and its rent paid, only while their attack is the
##    bigger one.
##  * THE RESCUE ("Return target permanent you control to its owner's
##    hand", a helpful bounce): a response's card
##    ([method AiPlayer._save_from_the_stack]), never a main-phase cast.
##  * THE SWEEP THAT ARRIVES WITH THE PERMANENT ("When this creature
##    enters, it deals N damage to each other creature" — Crater Hellion;
##    "At the beginning of your upkeep, … destroy all creatures" — Planar
##    Collapse): the symmetric-sweep pricing of urza_spells.gd, what each
##    side loses.
##  * THE TOLL ON A ROUTINE ACTION (player report 2026-11-26; "Whenever a
##    land enters, … deals 2 damage to that land's controller" — Ankh of
##    Mishra; "Whenever a player taps a land for mana, … deals 1 damage to
##    that player" — Manabarbs): no land drop, land fetch or payment that
##    costs our last life. Its own section, near the end of this file.
##  * THE SYMMETRIC PUNISHER (player report 2, 2026-11-26): a permanent
##    whose toll falls on "that player" — the land that arrives, the land
##    tapped, the lands left untapped, a count at each upkeep — is cast
##    only while the next turns of it take more of THEIR life than of
##    ours. Its own section, after the toll's.
##  * THE IDLE LANDS (the same report): under "X damage … the number of
##    untapped lands they controlled at the beginning of this turn" the
##    lands are tapped before our turn begins. Its own section.
##  * THE LOCK (the report's leftovers, 2026-11-27): a static that caps the
##    untap step ("players can't untap more than one land …" — Winter Orb,
##    Smoke, Damping Field, Static Orb) is cast only when it holds the
##    other side at least as hard as ours; under a land cap the lands are
##    a stock, not spent at the mana sink and kept for the better card.
##  * THE HAND (the same): an upkeep line that counts the cards in a hand
##    — a symmetric one (Storm World) is cast by the hands as they are; a
##    reward of ours (Ivory Tower) is read as the toll is, sign turned; a
##    land nothing will use stays in a hand that is paid for its size.
##    The last two sections.
##  * THE OTHER LOCKS AND TAXES (the leftovers of 0.70.14, 2026-11-27): a
##    lock a creature carries (Marble Titan), the untap of one chosen kind
##    (Storage Matrix), the flip (Sands of Time), the land a cast sets
##    back (Mana Breach), the drain (Mana Vortex); the weaker rungs under
##    a hand toll; the stock under a land cap in the main phase and in an
##    X. The file's last section.
##
## All of it behind [member AiProfile.forecasts_tactics], which every
## standard rung ships on: the gate off is the pilot as it was.

## The graveyard a library swap wants before it is worth a card.
const SHIFT_FLOOR := 15
## A library this small is about to lose us the game by itself.
const LIBRARY_PANIC := 3
## The draws a graveyard must hold before it may stand in for the library.
const CRYPT_FLOOR := 10
## The symmetric sweep's bar, urza_spells.gd's own.
const SWEEP_BAR := 3.0

const SHIFT_LINE := "Exile all cards from your library. Then shuffle your graveyard into your library"
const CRYPT_LINE := "If you would draw a card, return a card from your graveyard to your hand instead. If you can't, you lose the game"
const LASH_LINE := "cumulative upkeep, that player exiles all cards from their library"
const PEACE_LINE := "Creatures can't attack."

const TEMPEST_SPELLS := preload("res://engine/ai/tempest_spells.gd")

static var _arrival_burn: RegEx = null
static var _upkeep_wrath: RegEx = null


## Why [param inst], a card in the pilot's hand, is not cast in this
## position ("" when nothing here objects) — [method AiPlayer._cast_gate]'s
## last question.
static func cast_refusal(g: MtgGame, pilot, inst: CardInstance, planning := false) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	var data: CardData = inst.data
	# A toll the table takes for every cast ("the other locks and taxes").
	if g.has_trigger_listener(Mtg.EventType.SPELL_CAST):
		var tolled := cast_toll_refusal(g, pilot, inst)
		if tolled != "":
			return tolled
	# Under a cap on the untap step the lands are a stock ("the lock").
	if not planning and not g.untap_caps.is_empty():
		var kept := stock_refusal(g, pilot, inst)
		if kept != "":
			return kept
	var text: String = data.oracle_text
	if text.is_empty():
		return ""
	var me = g.players[pilot.pid]
	if not data.is_permanent_type() and text.contains(SHIFT_LINE):
		var pile: int = me.graveyard.size()
		var deck: int = me.library.size()
		if pile <= deck or (pile < SHIFT_FLOOR and deck > LIBRARY_PANIC):
			return "the graveyard is no library yet"
		return ""
	if not data.is_permanent_type():
		# A land put onto the battlefield into a toll that is our last life
		# ("the toll on a routine action", below).
		var puts := lands_put_by(text)
		if puts > 0 and land_put_is_lethal(g, pilot, null, puts):
			return "the land's arrival would cost our last life"
		return ""
	if text.contains(CRYPT_LINE):
		var pile: int = me.graveyard.size()
		if pile < CRYPT_FLOOR and pile <= int(me.library.size()):
			return "the graveyard would run dry"
		return ""
	if text.contains(LASH_LINE):
		return "its upkeep ends in the whole library"
	if stops_attacks(data) and not peace_wanted(g, pilot, null):
		return "our attack is the bigger one"
	if text.contains("untap") or text.contains("a land"):
		var held := lock_refusal(g, pilot, inst)
		if held != "":
			return held
	if not data.triggered_abilities.is_empty() \
			and (text.contains("damage to that") or text.contains("that player loses")):
		var why := punisher_refusal(g, pilot, inst)
		if why != "":
			return why
	return _arrival_sweep_refusal(g, pilot, inst)


## Does a static of [param data] stop every attack — "Creatures can't
## attack." and nothing more (a Moat's "without flying" is another card)?
static func stops_attacks(data: CardData) -> bool:
	for ability in data.static_abilities:
		if String(ability.text).strip_edges() == PEACE_LINE:
			return true
	return false


## Is "creatures can't attack" worth having right now? Yes while their
## creatures carry more power than ours ([param keeper], the permanent
## that makes the peace, left out of our count), and with no attack of
## ours to lose at all.
static func peace_wanted(g: MtgGame, pilot, keeper: CardInstance) -> bool:
	var ours := _attack_power(g, pilot.pid, keeper)
	return ours <= 0 or _attack_power(g, g.opponent_of(pilot.pid), null) > ours


static func _attack_power(g: MtgGame, who: int, skip: CardInstance) -> int:
	var total := 0
	for body in g.players[who].creatures():
		if body == skip or not g.is_present(body) or body.has_keyword(Mtg.Keyword.DEFENDER):
			continue
		total += maxi(body.cur_power, 0)
	return total


## An upkeep question this module answers: 1 yes, 0 no, -1 not ours
## ([method AiPlayer.answer_yes_no]). [param subject] is the permanent of
## ours the question names, [param hint] the asker's own answer.
static func upkeep_answer(g: MtgGame, pilot, prompt: String, subject: CardInstance,
		hint: bool) -> int:
	if not pilot.profile.forecasts_tactics or subject == null:
		return -1
	# The library is the price either way; paying takes the smaller part.
	if prompt.begins_with("Exile ") and prompt.contains("cumulative upkeep") \
			and subject.data.oracle_text.contains(LASH_LINE):
		return 1
	# The rent of a peace we no longer want is not paid.
	if hint and prompt.begins_with("Pay ") and stops_attacks(subject.data) \
			and not subject.cur_abilities_silenced \
			and not peace_wanted(g, pilot, subject):
		return 0
	return -1


## Is [param inst] a rescue — an instant whose one effect returns a
## permanent WE control to hand, marked helpful by its card? Its moment is
## a response to losing the permanent, not our main phase.
static func is_rescue(pilot, inst: CardInstance) -> bool:
	if not pilot.profile.forecasts_tactics or not inst.is_type(Mtg.CardType.INSTANT) \
			or inst.data.is_modal() or inst.data.spell_effects.size() != 1:
		return false
	var e: EffectBase = inst.data.spell_effects[0]
	return e is ReturnToHandEffect and e.ai_helpful and e.target_spec != null


## The sweep [param inst] brings with it, priced as the symmetric sweeps
## are: "" when it may be cast.
static func _arrival_sweep_refusal(g: MtgGame, pilot, inst: CardInstance) -> String:
	var text: String = inst.data.oracle_text
	if not text.contains("creature"):
		return ""
	if _arrival_burn == null:
		_arrival_burn = RegEx.create_from_string(
			"When this creature enters, it deals (\\d+) damage to each (other )?creature")
		_upkeep_wrath = RegEx.create_from_string(
			"At the beginning of your upkeep, [^\\n]*destroy all creatures")
	var damage := -1
	var found := _arrival_burn.search(text)
	if found != null:
		damage = int(found.get_string(1))
	elif _upkeep_wrath.search(text) == null:
		return ""
	var ours := _swept_worth(g, pilot, pilot.pid, damage)
	var theirs := _swept_worth(g, pilot, g.opponent_of(pilot.pid), damage)
	if damage < 0:
		# No body comes with it: a sweep and nothing else.
		return "" if theirs - ours >= SWEEP_BAR else "the sweep takes more of ours"
	# A body comes with it: refused when the sweep costs us more than the
	# body and their losses together are worth.
	if ours - theirs > Evaluator.card_value(inst.data):
		return "the sweep takes more of ours"
	return ""


## What [param who] loses to a sweep of [param damage] to each creature
## (every creature when negative), at [method Evaluator.permanent_value].
static func _swept_worth(g: MtgGame, pilot, who: int, damage: int) -> float:
	var total := 0.0
	for body in g.players[who].creatures():
		if not g.is_present(body):
			continue
		if damage >= 0 and body.cur_toughness - body.damage > damage:
			continue
		total += Evaluator.permanent_value(body, pilot.profile)
	return total


# ============================================ the toll on a routine action --
#
# PLAYER REPORT 2026-11-26: "AI will lose the game playing lands while Ankh
# of Mishra is out. Even if it's at 1 life remaining." A permanent on the
# table — either side's — that charges life for something the pilot does
# every turn without thinking: a land arriving ("Whenever a land enters,
# … deals 2 damage to that land's controller"), a second land played
# ("Whenever you play a land, if it wasn't the first … deals 1 damage to
# you"), a land tapped for mana ("Whenever a player taps a land for mana,
# … deals 1 damage to that player").
#
# HOW IT IS READ. What a trigger DOES lives in a Callable, so the amount
# and who pays are read off its printed line ([method life_toll_of_line],
# the precedent [method EffectIntent.toll_of_line] set); WHETHER it fires
# is the trigger's own condition, asked of the very event. A land DROP
# goes one better: once a line on the table says a toll may apply, the
# drop itself is run under the search journal and the life it cost is
# read off the game ([method land_drop_cost]) — every toll at once, an
# intervening "if" that counts the lands played, a shield that prevents
# it. With no such line on the table nothing is run and nothing changes.
#
# THE RULE ([method AiPlayer._land_toll_refuses], [method drop_refused]):
#  1. a drop that costs our last life is never made;
#  2. a land that unlocks a cast this turn is worth any toll short of that;
#  3. a LIGHT toll (under [constant TOLL_SHARE]'s part of our life) is the
#     price of the land and is paid — except for a land nothing of ours
#     will ever use ([method land_is_idle]: the table already makes the
#     most mana the deck's dearest card asks, and no ability wants more);
#  4. a HEAVY toll with nothing to cast this turn is paid only while it is
#     AFFORDABLE ([method toll_affordable]: what is left is out of burn
#     range, [constant SAFE_LIFE], and above their whole attack) and the
#     land is going somewhere: it is a step to a card in hand the hand's
#     lands reach between them ([method builds_to_a_cast]), or — player
#     report 2 — it is the second main phase and the hand is over its
#     size, so the cleanup would discard a card anyway.
# And at the discard itself ([method land_never_safe]) a land whose toll
# we cannot afford, or that nothing will use, goes before any spell.

## A toll of life / TOLL_SHARE or more is a heavy one.
const TOLL_SHARE := 4
## The answer for a drop that ends the game against us.
const TOLL_LETHAL := 1000000
## The life a paid toll must leave: one more than the era's burn spell.
const SAFE_LIFE := 4
## The lands a deck we cannot read is taken to want.
const LANDS_PLENTY := 6

const _TOLL_PAYERS := "(that land's controller|that player|its controller|you|each player|each opponent)"

static var _toll_damage: RegEx = null
static var _toll_loss: RegEx = null
static var _land_put: RegEx = null
static var _line_tolls: Dictionary = {}
static var _toll_lock := Mutex.new()


## What one printed trigger line takes from a player: `{"amount": n,
## "whom": "actor" | "you" | "opponents"}` — "actor" the player the event
## is about ("that land's controller", "that player", "each player"),
## "you" the trigger's own controller, "opponents" everyone else — or `{}`
## for a line that names no number of damage or life to a player.
static func life_toll_of_line(text: String) -> Dictionary:
	_toll_lock.lock()
	var known: Variant = _line_tolls.get(text)
	if known == null:
		if _toll_damage == null:
			_toll_damage = RegEx.create_from_string(
				"deals (\\d+) damage to " + _TOLL_PAYERS + "\\b")
			_toll_loss = RegEx.create_from_string(_TOLL_PAYERS + " loses? (\\d+) life")
		var out := {}
		var lower := text.to_lower()
		var hit := _toll_damage.search(lower)
		var amount := 0
		var payer := ""
		if hit != null:
			amount = int(hit.get_string(1))
			payer = hit.get_string(2)
		else:
			hit = _toll_loss.search(lower)
			if hit != null:
				amount = int(hit.get_string(2))
				payer = hit.get_string(1)
		if amount > 0:
			out = {"amount": amount, "whom": "you" if payer == "you" \
				else ("opponents" if payer == "each opponent" else "actor")}
		_line_tolls[text] = out
		known = out
	_toll_lock.unlock()
	return known


## What [param trig]'s line, on a permanent [param owner] controls, takes
## from [param pid] when [param pid] is the player its event is about.
static func _toll_on(trig: TriggeredAbility, owner: int, pid: int) -> int:
	if trig.is_mana_trigger or trig.text.is_empty():
		return 0
	var toll := life_toll_of_line(trig.text)
	if toll.is_empty():
		return 0
	match String(toll["whom"]):
		"you":
			return int(toll["amount"]) if owner == pid else 0
		"opponents":
			return int(toll["amount"]) if owner != pid else 0
	return int(toll["amount"])


## The life the table's printed lines charge [param pid] for a land
## arriving under its control — [param land] the land (null when it is not
## known yet, a search: then a line must itself speak of a land), [param
## played] whether it is PLAYED (a land put onto the battlefield is not).
## An arrival trigger's own condition is asked of the arrival; a "play a
## land" trigger is taken at its word, because its condition may count the
## plays this one has not made yet. 0 with nothing on the table to hear it.
static func arrival_tolls(g: MtgGame, pid: int, land: CardInstance, played: bool) -> int:
	var hears_entry := g.has_trigger_listener(Mtg.EventType.ENTERS_BATTLEFIELD)
	var hears_play := played and g.has_trigger_listener(Mtg.EventType.LAND_PLAYED)
	var total := 0
	if hears_entry or hears_play:
		var event: GameEvent = null
		if land != null:
			event = GameEvent.new(Mtg.EventType.ENTERS_BATTLEFIELD,
				{"instance": land, "controller": pid})
		for inst in g.all_battlefield():
			if inst.phased_out or inst == land:
				continue
			for trig in inst.cur_triggered_abilities:
				var entry: bool = hears_entry and trig.listens(Mtg.EventType.ENTERS_BATTLEFIELD)
				if not entry and not (hears_play and trig.listens(Mtg.EventType.LAND_PLAYED)):
					continue
				var toll := _toll_on(trig, inst.controller_id, pid)
				if toll <= 0:
					continue
				if entry:
					if event == null:
						if not trig.text.to_lower().contains("land"):
							continue
					elif not trig.matches(g, inst, event):
						continue
				total += toll
	# The land's own arrival ("When this land enters, it deals N damage to you").
	if land != null and land.zone != Mtg.Zone.BATTLEFIELD:
		for trig in land.data.triggered_abilities:
			if trig.listens(Mtg.EventType.ENTERS_BATTLEFIELD):
				total += _toll_on(trig, pid, pid)
	return total


## The life playing [param land] from hand would cost the pilot right now:
## 0 when no line on the table charges for it ([method arrival_tolls] — the
## cheap gate, and the whole of it in a game with no such permanent),
## otherwise the drop itself run under the search journal with the
## heuristic agents answering and everything put back, and the life it
## took read off the game. [constant TOLL_LETHAL] when it ends the game
## against us.
static func land_drop_cost(g: MtgGame, pilot, land: CardInstance) -> int:
	var pid: int = pilot.pid
	if arrival_tolls(g, pid, land, true) <= 0:
		return 0
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g._rec_turn()
	g._rec(g, &"agents")
	g.agents = [DecisionAgent.new(), DecisionAgent.new()]   # nobody is asked
	var before: int = g.players[pid].life
	var cost := 0
	if g.play_land(pid, land) == "":
		var guard := 0
		while not g.stack.is_empty() and not g.game_over and guard < 40:
			if g.pass_priority(g.priority_player) != "":
				break
			guard += 1
		cost = maxi(before - int(g.players[pid].life), 0)
		if (g.game_over and g.winner != pid) or g.players[pid].life <= 0:
			cost = TOLL_LETHAL
	g.unmake_to(mark)
	if not nested:
		g.end_search()
	return cost


## Would a land put onto the battlefield under the pilot's control — not
## played — cost its last life? [param count] lands, [param land] the land
## when it is known.
static func land_put_is_lethal(g: MtgGame, pilot, land: CardInstance, count := 1) -> bool:
	if not pilot.profile.forecasts_tactics:
		return false
	var toll := arrival_tolls(g, pilot.pid, land, false)
	return toll > 0 and toll * maxi(count, 1) >= int(g.players[pilot.pid].life)


## How many lands [param text], a spell's printed text, puts onto the
## battlefield under its caster's control from the library or the hand
## ("Search your library for a basic land card, put that card onto the
## battlefield", "… up to two basic land cards, put them onto the
## battlefield"): 0 for a text that puts none.
static func lands_put_by(text: String) -> int:
	if not text.contains("onto the battlefield") or not text.contains("land card"):
		return 0
	_toll_lock.lock()
	if _land_put == null:
		_land_put = RegEx.create_from_string(
			"(?:search your library for|put) (a|an|up to two|two|up to three|three)[^.]*?land cards?[^.]*?onto the battlefield")
	var found := _land_put.search(text.to_lower())
	_toll_lock.unlock()
	if found == null:
		return 0
	var word := found.get_string(1)
	return 3 if word.ends_with("three") else (2 if word.ends_with("two") else 1)


## The life the table charges [param pid] for tapping the lands of [param
## tap_plan] (rows of [param src], [method ManaPlanner.sources]) for mana:
## every "taps a land for mana" trigger that is not itself a mana ability,
## its condition asked of each tap, its line's number counted
## ([method AiPlayer._pain_kills] adds it to the pain of the sources).
static func tap_tolls(g: MtgGame, pid: int, src: Array, tap_plan: Array) -> int:
	if tap_plan.is_empty() or not g.has_trigger_listener(Mtg.EventType.TAPPED_FOR_MANA):
		return 0
	var charging: Array = []   # [trigger, its permanent, the toll]
	for inst in g.all_battlefield():
		if inst.phased_out:
			continue
		for trig in inst.cur_triggered_abilities:
			if not trig.listens(Mtg.EventType.TAPPED_FOR_MANA):
				continue
			var toll := _toll_on(trig, inst.controller_id, pid)
			if toll > 0:
				charging.append([trig, inst, toll])
	if charging.is_empty():
		return 0
	var total := 0
	for step in tap_plan:
		var land: CardInstance = step[0]
		if land == null or not land.is_land():
			continue
		var colour := 0
		for row in src:
			if row[0] == land and int(row[1]) == int(step[1]):
				colour = int(row[2])
				break
		var event := GameEvent.new(Mtg.EventType.TAPPED_FOR_MANA,
			{"instance": land, "controller": land.controller_id, "player": pid,
			"color": colour, "colors": [colour]})
		for entry in charging:
			if (entry[0] as TriggeredAbility).matches(g, entry[1], event):
				total += int(entry[2])
	return total


# ------------------------------------------------ the drop that is paid for --

## The most mana a card of ours asks: the dearest card in hand and in the
## registered list ([member AiPlayer.deck_study] — the list, never the
## library). An X spell in hand has no top; a deck we cannot read is taken
## to want [constant LANDS_PLENTY].
static func land_ceiling(g: MtgGame, pilot) -> int:
	var top := 0
	for card in g.players[pilot.pid].hand:
		if card.is_land():
			continue
		if card.data.cost.has_x:
			return 1 << 20
		top = maxi(top, card.data.cost.mana_value())
	var study: AiDeckStudy = pilot.deck_study
	if study != null:
		for mv in range(study.curve.size() - 1, 0, -1):
			if int(study.curve[mv]) > 0:
				top = maxi(top, mv)
				break
	return top if top > 0 else LANDS_PLENTY


## Is one more land of no use to us — the table already makes the most
## mana any card of ours asks ([method land_ceiling]) and no ability on it
## wants more?
static func land_is_idle(g: MtgGame, pilot) -> bool:
	return int(pilot._mana_reach(g, null)) >= land_ceiling(g, pilot) \
		and not pilot._has_ability_wanting_mana(g)


## Can we afford a toll of [param cost]: is what it leaves out of burn
## range ([constant SAFE_LIFE]) and above everything they could attack
## with?
static func toll_affordable(g: MtgGame, pilot, cost: int) -> bool:
	var left := int(g.players[pilot.pid].life) - cost
	return left >= SAFE_LIFE and left > _attack_power(g, g.opponent_of(pilot.pid), null)


## Is a land a step to a card in hand: one the table cannot pay for yet,
## that the lands in hand reach between them, at a toll of [param cost] a
## land we can afford for every one of those lands?
static func builds_to_a_cast(g: MtgGame, pilot, cost: int) -> bool:
	var me = g.players[pilot.pid]
	var lands := 0
	for card in me.hand:
		if card.is_land():
			lands += 1
	var reach := int(pilot._mana_reach(g, null))
	for card in me.hand:
		if card.is_land() or card.data.cost.has_x:
			continue
		var gap: int = card.data.cost.mana_value() - reach
		if gap >= 1 and gap <= lands and toll_affordable(g, pilot, cost * gap):
			return true
	return false


## THE RULE's points 2 to 4 (see the section's head): is playing [param
## land] refused at a toll of [param cost], which is not our last life?
static func drop_refused(g: MtgGame, pilot, land: CardInstance, cost: int) -> bool:
	var me = g.players[pilot.pid]
	if not land.data.enters_tapped \
			and pilot._land_unlocks_a_cast(g, pilot._mana_sources(g), land):
		return false
	if cost * TOLL_SHARE < int(me.life):
		return land_is_idle(g, pilot)
	if not toll_affordable(g, pilot, cost) or land_is_idle(g, pilot):
		return true
	if builds_to_a_cast(g, pilot, cost):
		return false
	# The cleanup would take a card anyway: the land is the better loss.
	return not (g.current_step() == Mtg.Step.MAIN2 and me.hand.size() > me.max_hand_size)


## At a discard: is [param land], in our hand, one we will not play — an
## arrival toll on the table we cannot afford, or a land nothing of ours
## will use while it costs life? Such a land goes before any spell
## ([method AiPlayer.answer_discard]).
static func land_never_safe(g: MtgGame, pilot, land: CardInstance) -> bool:
	if not pilot.profile.forecasts_tactics:
		return false
	var toll := arrival_tolls(g, pilot.pid, land, false)
	if toll <= 0:
		return false
	return not toll_affordable(g, pilot, toll) or land_is_idle(g, pilot)


# ================================================= the symmetric punisher --
#
# PLAYER REPORT 2, 2026-11-26: "It still casts its own Ankh of Mishra
# without counting the cost." A permanent whose trigger charges "that
# player" — whoever the event is about — is a card that hurts both seats,
# and it is worth a card only while it hurts THEM more. Four printed
# shapes are read, none by name, artifacts and enchantments only (a
# creature brings a body the toll is not the whole of):
#
#   arrival  "Whenever a land enters, … deals N damage to that land's
#            controller"                                  (Ankh of Mishra)
#   tap      "Whenever a player taps a land for mana, … deals N damage to
#            that player" — the line's own condition asked of each land
#            (Manabarbs; "taps an Island", Citadel of Pain's neighbours)
#   flat     "At the beginning of each player's upkeep, … deals N damage
#            to that player" / "that player loses N life"  (Copper Tablet)
#   count    "… each player's upkeep, … damage to that player equal to the
#            number of <things> they control": Swamps, artifacts, nonbasic
#            lands (Karma, Ancient Runes, Primal Order), and the untapped
#            lands of Power Surge.
#
# THE ESTIMATE — the toll each seat is expected to pay over the next
# [constant PUNISH_TURNS] turns of its own, from public things and our own
# hand and list only:
#
#   lands still to play   ours: the lands in hand plus [constant
#       PUNISH_TURNS] draws at the registered list's land share, no more
#       than one a turn and no more than we still WANT ([method
#       land_ceiling] less the mana the table makes — a deck of one- to
#       three-drops stops at three lands and its own Ankh then costs it
#       nothing). Theirs: every card in their hand and every draw is a
#       land [constant LAND_SHARE] of the time, one a turn, up to
#       [constant LANDS_PLENTY] on the table.
#   mana still to spend   ours: the mana values in hand plus [constant
#       UNSEEN_MANA] a draw; theirs: [constant UNSEEN_MANA] a card in hand
#       and a draw. Lands tapped = that, less what the nonland sources
#       make, no more than the lands allow; lands left idle = the lands
#       less that. (With mana burn off our own idle lands cost nothing:
#       they are tapped before our turn, [method idle_dump].)
#   counts                as they stand now, every turn.
#
# THE VERDICT ([method punisher_refusal]): each toll is taken as a share
# of the life it is taken from, and that life is first cut by one attack
# of the other side's creatures — so the beatdown's punisher is the better
# one. Not cast when it would charge them nothing, or when our share is
# more than theirs by over [constant PUNISH_MARGIN]; a tie is cast, the
# card is in the deck to be played.

## The turns of each seat a punisher is priced over.
const PUNISH_TURNS := 3
## How much more of our life than of theirs the toll may take.
const PUNISH_MARGIN := 0.1
## The share of unseen cards that are lands.
const LAND_SHARE := 0.4
## The mana an unseen card asks: a land four times in ten, about two else.
const UNSEEN_MANA := 1.2

static var _punisher_count: RegEx = null
static var _punishers: Dictionary = {}   # card name -> [[kind, amount, word, trigger index]]


## The punisher lines of [param data], `[kind, amount, counted word,
## trigger index]` each — kind "arrival", "tap", "flat", "count" or "hand"
## (amount the threshold, a fifth entry the slope). Cached by card name;
## numbers and words only.
static func punisher_lines(data: CardData) -> Array:
	_toll_lock.lock()
	var known: Variant = _punishers.get(data.card_name)
	_toll_lock.unlock()
	if known != null:
		return known
	var out: Array = []
	if not data.is_creature():
		for index in data.triggered_abilities.size():
			var trig: TriggeredAbility = data.triggered_abilities[index]
			if trig.is_mana_trigger or trig.text.is_empty():
				continue
			var lower := trig.text.to_lower()
			var toll := life_toll_of_line(trig.text)
			var actor: bool = not toll.is_empty() and String(toll["whom"]) == "actor"
			if trig.listens(Mtg.EventType.ENTERS_BATTLEFIELD):
				if actor and lower.contains("whenever a land enters"):
					out.append(["arrival", int(toll["amount"]), "", index])
			elif trig.listens(Mtg.EventType.TAPPED_FOR_MANA):
				if actor:
					out.append(["tap", int(toll["amount"]), "", index])
			elif trig.listens(Mtg.EventType.UPKEEP_START) \
					and lower.contains("each player's upkeep"):
				var hand := EffectIntent.hand_toll_of_line(trig.text)
				if not hand.is_empty():
					# The cards in a hand ("the hand", below): threshold, slope.
					out.append(["hand", int(hand["threshold"]), "", index, int(hand["slope"])])
				elif actor:
					out.append(["flat", int(toll["amount"]), "", index])
				elif lower.contains("damage to that player"):
					_toll_lock.lock()
					if _punisher_count == null:
						_punisher_count = RegEx.create_from_string(
							"the number of ([a-z ]+?) they control")
					var found := _punisher_count.search(lower)
					_toll_lock.unlock()
					if found != null:
						out.append(["count", 1, found.get_string(1), index])
	_toll_lock.lock()
	_punishers[data.card_name] = out
	_toll_lock.unlock()
	return out


## Why [param inst], a permanent card in the pilot's hand, is not cast for
## the toll it would put on both seats — "" for a card with no punisher
## line, a line this cannot count, or a toll that is theirs more than ours.
static func punisher_refusal(g: MtgGame, pilot, inst: CardInstance) -> String:
	var lines := punisher_lines(inst.data)
	if lines.is_empty():
		return ""
	var us: int = pilot.pid
	var them := g.opponent_of(us)
	var ours := 0.0
	var theirs := 0.0
	for line in lines:
		var trig: TriggeredAbility = inst.data.triggered_abilities[int(line[3])]
		var mine := _punisher_toll(g, pilot, inst, trig, line, us)
		var yours := _punisher_toll(g, pilot, inst, trig, line, them)
		if mine < 0.0 or yours < 0.0:
			return ""   # a count this does not know: the card as it was
		ours += mine
		theirs += yours
	if theirs <= 0.0:
		return "its toll would charge them nothing"
	var our_life := maxf(float(g.players[us].life) - _attack_power(g, them, null), 1.0)
	var their_life := maxf(float(g.players[them].life) - _attack_power(g, us, null), 1.0)
	if minf(ours, our_life) / our_life > minf(theirs, their_life) / their_life + PUNISH_MARGIN:
		return "its toll would take more of our life than of theirs"
	return ""


## What one punisher line is expected to take from [param who] over
## [constant PUNISH_TURNS] of its turns; negative for a count unknown here.
static func _punisher_toll(g: MtgGame, pilot, inst: CardInstance, trig: TriggeredAbility,
		line: Array, who: int) -> float:
	var amount := float(int(line[1]))
	var ours: bool = who == pilot.pid
	var turns := float(PUNISH_TURNS)
	match String(line[0]):
		"arrival":
			return amount * _lands_to_come(g, pilot, who)
		"flat":
			if trig.condition.is_valid() and not trig.condition.call(g, inst,
					GameEvent.new(Mtg.EventType.UPKEEP_START, {"player": who})):
				return 0.0
			return amount * turns
		"tap":
			var lands := 0
			for land in g.players[who].battlefield:
				if not land.is_land() or land.phased_out:
					continue
				if not trig.condition.is_valid() or trig.condition.call(g, inst,
						GameEvent.new(Mtg.EventType.TAPPED_FOR_MANA, {"instance": land,
						"controller": who, "player": who, "color": 0, "colors": [0]})):
					lands += 1
			var asked := _mana_to_spend(g, pilot, inst, who) - _free_mana(g, who) * turns
			return amount * clampf(asked, 0.0, float(lands) * turns)
		"hand":
			# The hands as they are now, ours less the card itself.
			var size: int = g.players[who].hand.size() - (1 if ours else 0)
			return float(EffectIntent.hand_toll_damage(
				{"slope": int(line[4]), "threshold": int(line[1])}, size)) * turns
	var word := String(line[2])
	if word == "untapped lands":
		# Our own idle lands are tapped away where that is free.
		if ours and not g.rules.mana_burn and pilot.profile.holds_instants:
			return 0.0
		var lands := 0
		for land in g.players[who].battlefield:
			if land.is_land() and not land.phased_out:
				lands += 1
		return maxf(float(lands) * turns - _mana_to_spend(g, pilot, inst, who), 0.0)
	var kind := word if Mtg.BASIC_LAND_COLORS.has(word) else word.trim_suffix("s")
	if word != "artifacts" and word != "nonbasic lands" \
			and not Mtg.BASIC_LAND_COLORS.has(kind):
		return -1.0
	var count := 0
	for perm in g.players[who].battlefield:
		if perm.phased_out:
			continue
		if word == "artifacts":
			if perm.is_type(Mtg.CardType.ARTIFACT):
				count += 1
		elif not perm.is_land():
			continue
		elif word == "nonbasic lands":
			if not DeckFormat.is_basic(perm.data.card_name):
				count += 1
		elif perm.has_subtype(kind):
			count += 1
	return float(count) * turns


## The lands [param who] is expected to play over the horizon (the
## section's head, "lands still to play").
static func _lands_to_come(g: MtgGame, pilot, who: int) -> float:
	var turns := float(PUNISH_TURNS)
	var reach := 0
	for perm in g.players[who].battlefield:
		if not perm.phased_out:
			reach += pilot._mana_per_tap(perm.cur_mana_abilities)
	var player = g.players[who]
	if who != pilot.pid:
		return clampf(float(player.hand.size() + PUNISH_TURNS) * LAND_SHARE, 0.0,
			minf(turns, float(maxi(LANDS_PLENTY - reach, 0))))
	var held := 0
	for card in player.hand:
		if card.is_land():
			held += 1
	var share := LAND_SHARE
	var study: AiDeckStudy = pilot.deck_study
	if study != null and not player.deck_names.is_empty():
		share = float(study.land_count) / float(player.deck_names.size())
	return clampf(float(held) + turns * share, 0.0,
		minf(turns, float(maxi(land_ceiling(g, pilot) - reach, 0))))


## The mana [param who] is expected to want over the horizon ("mana still
## to spend"); [param skip] is the card being judged, not counted.
static func _mana_to_spend(g: MtgGame, pilot, skip: CardInstance, who: int) -> float:
	var player = g.players[who]
	if who != pilot.pid:
		return float(player.hand.size() + PUNISH_TURNS) * UNSEEN_MANA
	var total := float(PUNISH_TURNS) * UNSEEN_MANA
	for card in player.hand:
		if card != skip and not card.is_land():
			total += float(card.data.cost.mana_value())
	return total


## The mana [param who]'s nonland permanents make a turn.
static func _free_mana(g: MtgGame, who: int) -> float:
	var made := 0
	for perm in g.players[who].battlefield:
		if perm.is_land() or perm.phased_out:
			continue
		var best := 0
		for ability in perm.cur_mana_abilities:
			var units := 0
			for pair in ability.produces:
				units += int(pair[1])
			best = maxi(best, units)
		made += best
	return float(made)


# ========================================================= the idle lands --
#
# PLAYER REPORT 2, 2026-11-26: "It does not read Power Surge." — "At the
# beginning of each player's upkeep, this enchantment deals X damage to
# that player, where X is the number of untapped lands they controlled at
# the beginning of this turn." The engine counts as the turn BEGINS, before
# the untap step ([method MtgGame._take_untap_census]), so a land is safe
# if it was tapped at any time since our last untap: in our own turn or in
# theirs.
#
# THE ARITHMETIC, PER RULE SET. A land tapped for mana nobody spends:
#   mana burn off ("Modern rules")      the pool empties, nothing is lost:
#       one damage saved a land. So every land still untapped at THEIR end
#       step — the last moment, with every instant and ability already
#       offered the mana — is tapped ([method idle_dump]).
#   mana burn on ("Modern rules, mana burn on", the default; "1997 — Fifth
#       Edition")   the mana burns for one life, now, where the surge
#       would have dealt one damage at our upkeep — the same point, sooner
#       and unpreventable. Never done. What helps there is SPENDING: a
#       cast is worth the surge it saves on top of its own worth
#       ([method idle_relief], added by [method AiPlayer._cast_value]).
# Nothing is read with no such line on the table.


## The damage a land of [param pid]'s left untapped as its turn begins
## costs it: one for every "number of untapped lands" upkeep line on the
## table whose condition names [param pid]'s upkeep. 0 with none.
static func idle_land_toll(g: MtgGame, pid: int) -> int:
	if not g.has_trigger_listener(Mtg.EventType.UPKEEP_START):
		return 0
	var total := 0
	for inst in g.all_battlefield():
		if inst.phased_out:
			continue
		for trig in inst.cur_triggered_abilities:
			if not trig.listens(Mtg.EventType.UPKEEP_START) \
					or not trig.text.contains("number of untapped lands") \
					or not trig.text.contains("damage to that player"):
				continue
			if trig.condition.is_valid() and not trig.condition.call(g, inst,
					GameEvent.new(Mtg.EventType.UPKEEP_START, {"player": pid})):
				continue
			total += 1
	return total


## What casting [param inst] saves us at our next upkeep under such a
## line, where idle lands cannot simply be tapped away: the lands its cost
## taps, at the reaper's rate for a point of our life. 0.0 otherwise.
static func idle_relief(g: MtgGame, pilot, inst: CardInstance) -> float:
	if not pilot.profile.forecasts_tactics \
			or not (g.rules.mana_burn or not pilot.profile.holds_instants):
		return 0.0
	var pid: int = pilot.pid
	var toll := idle_land_toll(g, pid)
	if toll <= 0:
		return 0.0
	var open := 0
	for land in g.players[pid].battlefield:
		if land.is_land() and not land.tapped and not land.phased_out:
			open += 1
	var spent := open if inst.data.cost.has_x else mini(open, inst.data.cost.mana_value())
	return float(toll * spent) * float(pilot._life_price(g.players[pid].life))


## Their end step, mana burn off, such a line on the table: tap every
## untapped land of ours that taps for nothing — no pain of its own, no
## toll on the tap, nothing that keeps it from untapping. The line said,
## or "" when there is nothing to do.
static func idle_dump(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics or g.rules.mana_burn:
		return ""
	var pid: int = pilot.pid
	if g.active_player == pid or not g.stack.is_empty():
		return ""
	# Under the flip a land tapped now is the land open next turn.
	if not flips(g, pid) and (idle_land_toll(g, pid) <= 0 or _untap_is_held(g, pid)):
		return ""
	var src: Array = pilot._mana_sources(g)
	var tapped := 0
	for row in src:
		var land: CardInstance = row[0]
		if land == null or not land.is_land() or land.tapped:
			continue
		if int(row[4]) != 0 or int(row[6]) > 0:
			continue   # stays tapped, hurts, or is spent by the tap
		if tap_tolls(g, pid, src, [ManaPlanner.step_of(row)]) > 0:
			continue
		if g.tap_for_mana(pid, land, int(row[1]), int(row[2])) == "":
			tapped += 1
	if tapped <= 0:
		return ""
	return "tapped %d idle land%s" % [tapped, "" if tapped == 1 else "s"]


## Could a land tapped now stay tapped past our untap step — a skipped
## step, or any permanent whose text holds untapping back? Then the lands
## are left alone.
static func _untap_is_held(g: MtgGame, pid: int) -> bool:
	var me = g.players[pid]
	if me.skips_untap_step or me.skip_untap_steps > 0 or not g.untap_kind_choices.is_empty():
		return true
	for inst in g.all_battlefield():
		var text: String = inst.data.oracle_text
		if text.contains("untap") and (text.contains("can't untap") \
				or text.contains("don't untap") or text.contains("doesn't untap") \
				or text.contains("untap step")):
			return true
	return false


# =============================================================== the lock --
#
# PLAYER REPORT 2's leftovers (2026-11-27): "Winter Orb and Stasis-style
# locks". A static that CAPS the untap step — "players can't untap more
# than one land during their untap steps" (Winter Orb), "… one creature …"
# (Smoke), "… one artifact …" (Damping Field), "… two permanents …"
# (Static Orb) — moves nothing on the table the moment it lands, so the
# board projection that prices every other symmetric static
# (tempest_spells.gd `symmetric_static_choice`: Meekstone, Choke, Back to
# Basics, by what stays tapped) reads it as nothing. The freeze of the
# whole step (Stasis) is the lock reader's and stays there
# ([method AiPlayer._lock_worth], [member AiProfile.pays_the_rent]).
#
# CASTING OUR OWN ([method lock_refusal]). What the cap HOLDS of each side
# over [constant PUNISH_TURNS] turns, from the public table and our own
# hand:
#   land       the mana the side still wants ([method _mana_to_spend], less
#              what its nonland sources make) beyond what the cap leaves
#              it: the lands untapped now — ours less the lands the lock
#              itself is paid with — and the cap's untaps a turn. A side
#              that tapped out last turn is the one the Orb catches.
#   creature   the power of its attackers (no defender, no vigilance)
#              beyond the best the cap lets untap.
#   artifact   its artifacts that tap for something, beyond the cap.
#   permanent  the land reading at the cap, and every attacker's power.
# Not cast when it holds something of ours and nothing of theirs, or more
# of ours than of theirs by over [constant LOCK_MARGIN] — with the bigger
# attack on the table already, a mana lock may cost us [constant LOCK_LEAD]
# more: the side ahead wants the game to stand still.
#
# LIVING UNDER ONE, whoever owns it ([method land_refill]): the lands are
# a STOCK, not an income. Two cheap rules and no more:
#   1. the mana sink is no sink ([method sink_refused]): an activation at
#      their end step that taps more lands than our untap gives back is
#      not made while a card in hand still wants the mana;
#   2. the mana is saved for the better card ([method stock_refusal]): a
#      permanent is not cast when a card in hand worth [constant
#      STOCK_EDGE] times as much is within [constant STOCK_TURNS] turns of
#      the stock and this cast would put it a turn further off. A creature
#      is cast all the same while their attack is the bigger one.
# Nothing is read while [member MtgGame.untap_caps] is empty.

## How much more of our mana than of theirs a lock may hold while our
## attack is the bigger one.
const LOCK_LEAD := 2.0
## The difference that is no difference.
const LOCK_MARGIN := 0.5
## How far off (our turns) a card may be and still have the mana kept.
const STOCK_TURNS := 2
## How much more than the cast at hand that card must be worth.
const STOCK_EDGE := 1.5

static var _untap_cap: RegEx = null
static var _caps: Dictionary = {}   # card name -> [kind, cap] or []


## The untap cap a static of [param data] prints: `[kind, cap]` — kind
## "land", "creature", "artifact" or "permanent" — or `[]`. Cached by card
## name.
static func untap_cap_of(data: CardData) -> Array:
	_toll_lock.lock()
	var known: Variant = _caps.get(data.card_name)
	if known == null:
		if _untap_cap == null:
			_untap_cap = RegEx.create_from_string(
				"players can't untap more than (one|two|three|\\d+) (land|creature|artifact|permanent)s? during their untap steps")
		var out: Array = []
		for ability in data.static_abilities:
			var found := _untap_cap.search(String(ability.text).to_lower())
			if found == null:
				continue
			var word := found.get_string(1)
			var cap := 1 if word == "one" else (2 if word == "two" \
				else (3 if word == "three" else int(word)))
			out = [found.get_string(2), cap]
			break
		_caps[data.card_name] = out
		known = out
	_toll_lock.unlock()
	return known


## Why [param inst], a permanent card in the pilot's hand that caps the
## untap step, is not cast: "" for a card that caps nothing, a lock that
## holds nothing of ours, or one that holds them at least as hard.
static func lock_refusal(g: MtgGame, pilot, inst: CardInstance) -> String:
	var cap := lock_shape_of(inst.data)
	if cap.is_empty():
		return ""
	if String(cap[0]) == "carried":
		return _carried_refusal(g, pilot, inst)
	var us: int = pilot.pid
	var them := g.opponent_of(us)
	var ours := _held_by_cap(g, pilot, inst, cap, us)
	if ours <= 0.0:
		return ""
	var theirs := _held_by_cap(g, pilot, inst, cap, them)
	if theirs <= 0.0:
		return "the lock would hold our side alone"
	var slack := LOCK_MARGIN
	if String(cap[0]) != "creature" \
			and _attack_power(g, us, null) > _attack_power(g, them, null):
		slack += LOCK_LEAD
	if ours > theirs + slack:
		return "the lock would hold more of ours than of theirs"
	return ""


## What the cap [param cap] of [param inst] holds of [param who] over
## [constant PUNISH_TURNS] turns (the section's head).
static func _held_by_cap(g: MtgGame, pilot, inst: CardInstance, cap: Array, who: int) -> float:
	var kind := String(cap[0])
	var room := int(cap[1])
	var turns := float(PUNISH_TURNS)
	var held := 0.0
	if kind == "land" or kind == "permanent":
		var lands := 0
		var open := 0
		for land in g.players[who].battlefield:
			if land.is_land() and not land.phased_out:
				lands += 1
				if not land.tapped:
					open += 1
		var free := _free_mana(g, who) if kind == "land" else 0.0
		var want := minf(_mana_to_spend(g, pilot, inst, who) - free * turns,
			float(lands) * turns)
		if who == pilot.pid:
			open -= clampi(inst.data.cost.mana_value() - int(free), 0, open)
		held += maxf(want - float(open) - float(room) * turns, 0.0)
	if kind == "creature" or kind == "permanent":
		var powers: Array = []
		for body in g.players[who].creatures():
			if g.is_present(body) and body.cur_power > 0 \
					and not body.has_keyword(Mtg.Keyword.DEFENDER) \
					and not body.has_keyword(Mtg.Keyword.VIGILANCE):
				powers.append(int(body.cur_power))
		powers.sort()
		powers.reverse()
		for index in range(room if kind == "creature" else 0, powers.size()):
			held += float(int(powers[index]))
	if kind == "artifact":
		var working := 0
		for perm in g.players[who].battlefield:
			if perm == inst or perm.phased_out or not perm.is_type(Mtg.CardType.ARTIFACT):
				continue
			var taps: bool = not perm.cur_mana_abilities.is_empty()
			for ability in perm.cur_activated_abilities:
				if ability.tap_cost:
					taps = true
			if taps:
				working += 1
		held += float(maxi(working - room, 0))
	if kind == "choice" or kind == "flip" or kind == "drain" or kind == "breach":
		held += _held_by_shape(g, pilot, inst, kind, who)
	return held


## The lands [param pid] may untap in its untap step under the caps in
## force (the land's and the permanent's, the tighter): -1 with no cap.
static func land_refill(g: MtgGame, _pid: int) -> int:
	var refill := -1
	if g.untap_caps.is_empty():
		return refill
	for kind in ["land", "permanent"]:
		var cap := int(g.untap_caps.get(kind, -1))
		if cap >= 0 and (refill < 0 or cap < refill):
			refill = cap
	return refill


## At the mana sink (their end step): is an activation paid with [param
## plan] refused, because it taps more lands than our untap step gives
## back and a card in hand still wants the mana?
static func sink_refused(g: MtgGame, pilot, plan: Array) -> bool:
	if g.untap_caps.is_empty() or plan.is_empty() or not pilot.profile.forecasts_tactics:
		return false
	var refill := land_refill(g, pilot.pid)
	if refill < 0:
		return false
	var me = g.players[pilot.pid]
	var spent := 0
	for step in plan:
		var land: CardInstance = step[0]
		if land != null and land.is_land():
			spent += 1
	if spent <= 0:
		return false
	var tapped := 0
	for land in me.battlefield:
		if land.is_land() and land.tapped and not land.phased_out:
			tapped += 1
	if spent <= maxi(refill - tapped, 0):
		return false
	for card in me.hand:
		if not card.is_land():
			return true
	return false


## Under a land cap: why [param inst], a permanent card in hand, is not
## cast now — the mana it taps is kept for a better card in hand that is
## close ("living under one", rule 2). "" otherwise.
static func stock_refusal(g: MtgGame, pilot, inst: CardInstance) -> String:
	var data: CardData = inst.data
	if not data.is_permanent_type() or data.is_land() or data.cost.has_x:
		return ""
	var pid: int = pilot.pid
	var refill := land_refill(g, pid)
	if refill < 0:
		return ""
	var me = g.players[pid]
	var open_lands := 0
	var mana := 0
	for perm in me.battlefield:
		if perm.tapped or perm.phased_out:
			continue
		var made: int = pilot._mana_per_tap(perm.cur_mana_abilities)
		mana += made
		if perm.is_land() and made > 0:
			open_lands += 1
	var price: int = data.cost.mana_value()
	if price > mana:
		return ""
	var spent := clampi(price - (mana - open_lands), 0, open_lands)
	if spent <= 0:
		return ""
	var them := g.opponent_of(pid)
	if data.is_creature() and _attack_power(g, them, null) > _attack_power(g, pid, null):
		return ""   # the body is wanted now
	if _better_card_waits(g, pilot, inst, mana, spent, refill,
			float(pilot._card_value(data)) * STOCK_EDGE):
		return "the mana is kept for a better card"
	return ""


## Is a card in hand (not [param inst]) worth [param bar] or more out of
## reach of [param mana] now, within [constant STOCK_TURNS] turns of the
## stock at [param refill] lands a turn (one more with a land in hand),
## and put a turn further off by [param spent] lands tapped now?
static func _better_card_waits(g: MtgGame, pilot, inst: CardInstance, mana: int,
		spent: int, refill: int, bar: float) -> bool:
	var me = g.players[pilot.pid]
	var rate := refill
	for card in me.hand:
		if card.is_land():
			rate += 1
			break
	if rate <= 0:
		return false
	for card in me.hand:
		if card == inst or card.is_land() or card.data.cost.has_x:
			continue
		var need: int = card.data.cost.mana_value() - mana
		if need <= 0 or float(pilot._card_value(card.data)) < bar:
			continue
		var wait := ceili(float(need) / float(rate))
		if wait > STOCK_TURNS or ceili(float(need + spent) / float(rate)) <= wait:
			continue
		if cast_refusal(g, pilot, card, true) != "":
			continue   # a card we would not cast is not saved for
		return true
	return false


# =============================================================== the hand --
#
# The same leftovers: "Storm World, Ivory Tower, Viseling, Iron Maiden" —
# an upkeep line that counts THE CARDS IN A HAND. The toll's two numbers
# are [method EffectIntent.hand_toll_of_line]'s (slope and threshold: the
# squeeze of Black Vise and Iron Maiden, the stretch of The Rack, Wheel of
# Torture and Storm World), and under one on the table the pilot already
# draws and casts by them ([method AiPlayer._vise_room], [method
# AiPlayer._vise_relief], [member AiProfile.minds_the_vise]). Added here:
#   * THE REWARD ("you gain X life, where X is the number of cards in your
#     hand minus 4" — Ivory Tower), read as the same pair with the sign
#     turned ([method hand_reward_of_line]): a card that leaves a paying
#     hand is charged the life it no longer gains ([method cast_relief]).
#   * CASTING OUR OWN: a line at EACH player's upkeep (Storm World) is a
#     symmetric punisher ([method punisher_lines], kind "hand") and is
#     priced as the others are, by the hands as they are now — ours less
#     the card itself. A line at the opponent's upkeep alone is no own
#     goal and is cast as before.
#   * THE LAND THAT STAYS IN HAND ([method land_kept_in_hand]): while a
#     smaller hand costs us life at our next upkeep — a stretch on the
#     table, or a reward of ours that pays — a land nothing of ours will
#     use ([method land_is_idle]) is not played.
# Nothing is read with no upkeep trigger on the table.

static var _hand_reward: RegEx = null
static var _hand_rewards: Dictionary = {}


## A printed upkeep line that GAINS its controller life counted off the
## cards in their hand, as [method EffectIntent.hand_toll_of_line]'s pair
## `{"slope": 1, "threshold": n}`; `{}` for any other line.
static func hand_reward_of_line(text: String) -> Dictionary:
	_toll_lock.lock()
	var known: Variant = _hand_rewards.get(text)
	if known == null:
		var out := {}
		var lower := text.to_lower()
		if lower.contains("you gain") and lower.contains("cards in your hand"):
			if _hand_reward == null:
				_hand_reward = RegEx.create_from_string(
					"number of cards in your hand minus ([0-9]+)")
			var found := _hand_reward.search(lower)
			if found != null:
				out = {"slope": 1, "threshold": int(found.get_string(1))}
		_hand_rewards[text] = out
		known = out
	_toll_lock.unlock()
	return known


## The life [param pid]'s next upkeep takes from it at a hand of [param
## size]: every hand toll on the table that beats at its upkeep, less
## every hand reward of its own. Negative is life gained.
static func hand_beat(g: MtgGame, pid: int, size: int, rewards := true) -> int:
	var total := 0
	for inst in g.all_battlefield():
		if inst.phased_out:
			continue
		for trig in inst.cur_triggered_abilities:
			if not trig.listens(Mtg.EventType.UPKEEP_START) or trig.text.is_empty():
				continue
			var toll := EffectIntent.hand_toll_of_line(trig.text)
			var reward := {}
			if toll.is_empty():
				if inst.controller_id != pid or not rewards:
					continue
				reward = hand_reward_of_line(trig.text)
				if reward.is_empty():
					continue
			if trig.condition.is_valid() and not trig.condition.call(g, inst,
					GameEvent.new(Mtg.EventType.UPKEEP_START, {"player": pid})):
				continue
			total += EffectIntent.hand_toll_damage(toll, size) \
				- EffectIntent.hand_toll_damage(reward, size)
	return total


## Does one card fewer in the pilot's hand cost it life at its next
## upkeep?
static func hand_is_held(g: MtgGame, pilot) -> bool:
	if not g.has_trigger_listener(Mtg.EventType.UPKEEP_START):
		return false
	var size: int = g.players[pilot.pid].hand.size()
	return hand_beat(g, pilot.pid, size - 1) > hand_beat(g, pilot.pid, size)


## Is [param land] better kept in hand: a smaller hand costs us life, the
## land is one nothing of ours will use, and the cleanup is not about to
## take a card anyway ([method AiPlayer._land_toll_refuses])?
static func land_kept_in_hand(g: MtgGame, pilot, _land: CardInstance) -> bool:
	if not pilot.profile.forecasts_tactics or not hand_is_held(g, pilot):
		return false
	var me = g.players[pilot.pid]
	if me.hand.size() > me.max_hand_size:
		return false
	return land_is_idle(g, pilot)


## What casting [param inst] is worth on top of its own worth for what
## the table charges or pays ([method AiPlayer._cast_value]): the idle
## lands it taps under a surge ([method idle_relief]), less the life a
## hand reward of ours no longer pays for the card that left the hand.
static func cast_relief(g: MtgGame, pilot, inst: CardInstance) -> float:
	var relief := idle_relief(g, pilot, inst)
	if not pilot.profile.forecasts_tactics or inst.zone != Mtg.Zone.HAND \
			or not g.has_trigger_listener(Mtg.EventType.UPKEEP_START):
		return relief
	var pid: int = pilot.pid
	var me = g.players[pid]
	# Under the flip a land tapped now is a land open next turn.
	if me.skips_untap_step and g.active_player == pid and flips(g, pid):
		var open := 0
		for land in me.battlefield:
			if land.is_land() and not land.tapped and not land.phased_out:
				open += 1
		relief += FLIP_LAND * float(open if inst.data.cost.has_x \
			else mini(open, inst.data.cost.mana_value()))
	var size: int = me.hand.size()
	var lost := 0
	for perm in me.battlefield:
		if perm.phased_out:
			continue
		for trig in perm.cur_triggered_abilities:
			if not trig.listens(Mtg.EventType.UPKEEP_START) or trig.text.is_empty():
				continue
			var reward := hand_reward_of_line(trig.text)
			if reward.is_empty():
				continue
			if trig.condition.is_valid() and not trig.condition.call(g, perm,
					GameEvent.new(Mtg.EventType.UPKEEP_START, {"player": pid})):
				continue
			lost += EffectIntent.hand_toll_damage(reward, size) \
				- EffectIntent.hand_toll_damage(reward, size - 1)
	return relief - float(lost) * float(pilot._life_price(me.life))


# ================================================ the other locks and taxes --
#
# THE LEFTOVERS OF 0.70.14 (2026-11-27). Five more printed shapes
# ([method lock_shape_of]), each on both sides of the table:
#   carried  a creature whose static keeps creatures from untapping
#            ("Creatures with power 3 or greater don't untap during their
#            controllers' untap steps" — Marble Titan). The noncreature
#            statics of that kind are priced by the board put under the
#            search journal (tempest_spells.gd `static_projection`); the
#            creature is priced the same way ([method _carried_refusal]):
#            not cast when it holds our side, and ours more than theirs.
#   choice   "each player chooses artifact, creature, or land during their
#            untap step" (Storage Matrix): a side keeps the biggest of its
#            three — the land mana it wants a turn, its attackers' power,
#            its working artifacts — and is held the other two. Under one
#            the kind is chosen by what untapping it buys this turn
#            ([method untap_kind]), the engine's default — the kind with
#            most tapped — only on a tie.
#   flip     "untaps each tapped … and taps each untapped …" at upkeep
#            (Sands of Time): what a side leaves untapped is what it loses
#            next turn — their open lands and attackers now, ours beyond
#            the card's price and the bodies that cannot attack. Under one
#            ([method flips]) a land tapped now is the land open next
#            turn: the idle lands are tapped at their end step where that
#            is free ([method idle_dump]), and a cast is worth half a
#            point a land it taps where it is not ([method cast_relief]).
#   drain    "each player's upkeep, that player sacrifices a land" (Mana
#            Vortex): the mana a side still wants beyond what its
#            shrinking lands make — ours a land shorter and a turn later.
#   breach   "Whenever a player casts a spell, that player returns a land
#            they control to its owner's hand" (Mana Breach): the spells a
#            side still has to cast beyond the one a turn whose land the
#            land drop puts back.
# The verdict is the lock's ([method lock_refusal]): not cast when it
# holds our side alone, or ours more than theirs — with the bigger attack
# on the table a little more of ours is allowed.
#
# UNDER A TOLL ON EVERY CAST ([method cast_toll_refusal]), whoever owns
# it: a cast that costs our last life is never made (Spellshock's two at
# two life); a land set back is free when the land drop puts it back (no
# other land in hand) or the lands left still make everything our cards
# ask ([method land_ceiling]); otherwise a spell worth less than
# [constant LAND_BACK] waits. A creature against the bigger attack, an X
# and burn that ends the game are cast all the same.
#
# THE WEAKER RUNGS UNDER A HAND TOLL. [member AiProfile.minds_the_vise]
# (the room, the relief at the reaper's rate, the price of the permanent)
# is the Sorcerer's and the Wizard's by the ladder's design
# (docs/ai-difficulty.md). A rung without it gets the two obvious parts:
#   * over the limit of a squeeze its turn does not stop developing — the
#     mistake roll is rolled as ever and not taken ([method
#     fumble_spared]);
#   * under a stretch a cast is charged a flat [constant STRETCH_PRICE] a
#     point it hands the toll over [constant PUNISH_TURNS] upkeeps, in the
#     main-phase ranking alone ([method stretch_charge]) — a Healing Salve
#     stays in hand, a creature or a spell that takes a permanent is cast.
# Nothing of the room, the wheel, the removal's aim: those stay off.
#
# THE STOCK, IN THE MAIN PHASE AND IN AN X (under a land cap, "the lock"):
# a main-phase activation ([method main_sink_refused]) and a sized X spell
# ([method x_refusal]) that tap capped lands are not made while a card in
# hand worth [constant STOCK_EDGE] times as much is within [constant
# STOCK_TURNS] turns of the stock and the taps would put it a turn
# further off. What wins the game is never held.

## What a land set back to hand costs: a spell worth less waits.
const LAND_BACK := 3.0
## The flat charge, a point of life, of the rungs that do not price it.
const STRETCH_PRICE := 1.0
## What a land tapped under the flip is worth: the mana of next turn.
const FLIP_LAND := 0.5

const CHOICE_LINE := "chooses artifact, creature, or land during their untap step"
const BREACH_LINE := "that player returns a land they control to its owner's hand"
const DRAIN_LINE := "each player's upkeep, that player sacrifices a land"
const CARRIED_LINE := "don't untap during their controllers' untap steps"
const CAST_TOLL_HEAD := "whenever a player casts a spell"

static var _shapes: Dictionary = {}       # card name -> [kind, n] or []
static var _cast_tolls: Dictionary = {}   # trigger line -> [land, life]


## The lock or tax [param data] prints: an untap cap ([method
## untap_cap_of]) or `["carried" | "choice" | "flip" | "drain" | "breach",
## 0]` (the section's head); `[]` for any other card. Cached by card name.
static func lock_shape_of(data: CardData) -> Array:
	_toll_lock.lock()
	var known: Variant = _shapes.get(data.card_name)
	_toll_lock.unlock()
	if known != null:
		return known
	var out: Array = untap_cap_of(data)
	if out.is_empty():
		for ability in data.static_abilities:
			var line := String(ability.text).to_lower()
			if line.contains(CHOICE_LINE):
				out = ["choice", 0]
			elif data.is_creature() and line.contains(CARRIED_LINE):
				out = ["carried", 0]
		for trig in data.triggered_abilities:
			var line := String(trig.text).to_lower()
			if trig.listens(Mtg.EventType.UPKEEP_START):
				if _is_flip(line):
					out = ["flip", 0]
				elif line.contains(DRAIN_LINE):
					out = ["drain", 0]
			elif trig.listens(Mtg.EventType.SPELL_CAST) and int(cast_toll_of_line(trig.text)[0]) > 0:
				out = ["breach", 0]
	_toll_lock.lock()
	_shapes[data.card_name] = out
	_toll_lock.unlock()
	return out


static func _is_flip(lower: String) -> bool:
	return lower.contains("untaps each tapped") and lower.contains("taps each untapped")


## `[lands, life]` a printed "Whenever a player casts a spell, …" line
## takes from the caster; `[0, 0]` for any other line.
static func cast_toll_of_line(text: String) -> Array:
	_toll_lock.lock()
	var known: Variant = _cast_tolls.get(text)
	_toll_lock.unlock()
	if known != null:
		return known
	var out: Array = [0, 0]
	var lower := text.to_lower()
	if lower.begins_with(CAST_TOLL_HEAD):
		if lower.contains(BREACH_LINE):
			out[0] = 1
		else:
			var toll := life_toll_of_line(text)
			if not toll.is_empty() and String(toll["whom"]) == "actor":
				out[1] = int(toll["amount"])
	_toll_lock.lock()
	_cast_tolls[text] = out
	_toll_lock.unlock()
	return out


## `[lands, life]` the table takes from a player for one cast: every such
## line on the battlefield (a line with a condition of its own is not
## guessed at).
static func cast_tolls(g: MtgGame) -> Array:
	var out: Array = [0, 0]
	if not g.has_trigger_listener(Mtg.EventType.SPELL_CAST):
		return out
	for perm in g.all_battlefield():
		if perm.phased_out:
			continue
		for trig in perm.cur_triggered_abilities:
			if not trig.listens(Mtg.EventType.SPELL_CAST) or trig.text.is_empty() \
					or trig.condition.is_valid():
				continue
			var toll := cast_toll_of_line(trig.text)
			out[0] = int(out[0]) + int(toll[0])
			out[1] = int(out[1]) + int(toll[1])
	return out


## Why [param inst] is not cast into the toll the table takes for every
## cast ("under a toll on every cast"); "" with no such line in play.
static func cast_toll_refusal(g: MtgGame, pilot, inst: CardInstance) -> String:
	var toll := cast_tolls(g)
	var back := int(toll[0])
	if back <= 0 and int(toll[1]) <= 0:
		return ""
	var pid: int = pilot.pid
	var me = g.players[pid]
	if int(toll[1]) >= int(me.life):
		return "the cast would cost our last life"
	var data: CardData = inst.data
	if back <= 0 or data.cost.has_x or data.is_land():
		return ""
	var lands := 0
	for land in me.battlefield:
		if land.is_land() and not land.phased_out:
			lands += 1
	if lands <= 0:
		return ""
	var held := 0
	for card in me.hand:
		if card.is_land():
			held += 1
	# The land drop puts the one land back: this turn's, or the next's.
	if back == 1 and held == 0 and (g.active_player != pid or g.land_drop_available(pid)):
		return ""
	if int(pilot._mana_reach(g, null)) - back >= land_ceiling(g, pilot):
		return ""   # lands in plenty: nothing of ours asks for the one set back
	if float(pilot._card_value(data)) >= LAND_BACK * float(back):
		return ""
	var them := g.opponent_of(pid)
	if data.is_creature() and _attack_power(g, them, null) > _attack_power(g, pid, null):
		return ""   # the body is wanted now
	if not data.is_permanent_type() and pilot._lethal_burn(g, pilot._intent_of(inst), 0):
		return ""
	return "the spell is not worth the land it sets back"


## The creature that carries a lock ("carried"): the board with it on the
## battlefield, each side priced before and after. Not cast when it costs
## our side, and ours more than theirs.
static func _carried_refusal(g: MtgGame, pilot, inst: CardInstance) -> String:
	if inst.zone != Mtg.Zone.HAND:
		return ""
	var swing: Dictionary = TEMPEST_SPELLS.static_projection(g, pilot, inst)
	var ours := float(swing["ours"])
	if ours < -TEMPEST_SPELLS.STATIC_EPSILON \
			and ours - float(swing["theirs"]) < -TEMPEST_SPELLS.STATIC_EPSILON:
		return "the lock would hold more of ours than of theirs"
	return ""


## What a lock of [param kind] — "choice", "flip", "drain" or "breach" —
## holds of [param who] (the section's head); [param inst] is the card in
## the pilot's hand.
static func _held_by_shape(g: MtgGame, pilot, inst: CardInstance, kind: String,
		who: int) -> float:
	var turns := float(PUNISH_TURNS)
	var ours: bool = who == pilot.pid
	var player = g.players[who]
	var lands := 0
	var open := 0
	for land in player.battlefield:
		if land.is_land() and not land.phased_out:
			lands += 1
			if not land.tapped:
				open += 1
	var free := _free_mana(g, who)
	if kind == "breach":
		var spells := float(PUNISH_TURNS) * (1.0 - LAND_SHARE)
		if ours:
			for card in player.hand:
				if card != inst and not card.is_land():
					spells += 1.0
		else:
			spells += float(player.hand.size()) * (1.0 - LAND_SHARE)
		return maxf(spells - turns, 0.0) if lands > 0 else 0.0
	var want := clampf(_mana_to_spend(g, pilot, inst, who) - free * turns, 0.0,
		float(lands) * turns)
	if kind == "drain":
		# Their upkeep is the next one; ours follows the land the cast eats.
		var left := lands - 1 if ours else lands
		var made := 0
		for turn in range(1, PUNISH_TURNS + 1):
			made += maxi(left - turn, 0)
		return maxf(want - float(made), 0.0)
	var attack := 0.0
	var home := 0.0   # the flip: bodies that stay untapped into the upkeep
	var past_combat: bool = g.active_player != pilot.pid \
		or g.current_step() > Mtg.Step.DECLARE_ATTACKERS
	for body in player.creatures():
		if not g.is_present(body) or body.cur_power <= 0 \
				or body.has_keyword(Mtg.Keyword.DEFENDER):
			continue
		if not body.has_keyword(Mtg.Keyword.VIGILANCE):
			attack += float(body.cur_power)
		if not body.tapped and (not ours or body.summoning_sick or past_combat):
			home += float(body.cur_power)
	if kind == "flip":
		if ours:
			open -= clampi(inst.data.cost.mana_value() - int(free), 0, open)
		return float(open) + home
	# The choice: the biggest of the three is kept, the others are held.
	var working := 0.0
	for perm in player.battlefield:
		if perm == inst or perm.phased_out or perm.is_land() or perm.is_creature() \
				or not perm.is_type(Mtg.CardType.ARTIFACT):
			continue
		for ability in perm.cur_activated_abilities:
			if ability.tap_cost:
				working = working + 1.0
				break
	var mana := want / turns + free   # the nonland sources tap as well
	return mana + attack + working - maxf(mana, maxf(attack, working))


## Does an upkeep line on the table flip [param pid]'s permanents — untap
## the tapped, tap the untapped?
static func flips(g: MtgGame, pid: int) -> bool:
	if not g.players[pid].skips_untap_step \
			or not g.has_trigger_listener(Mtg.EventType.UPKEEP_START):
		return false
	for perm in g.all_battlefield():
		if perm.phased_out:
			continue
		for trig in perm.cur_triggered_abilities:
			if trig.listens(Mtg.EventType.UPKEEP_START) \
					and _is_flip(String(trig.text).to_lower()):
				return true
	return false


## The kind to untap under "chooses artifact, creature, or land"
## ([method AiPlayer.answer_option]; [param options] the engine's three
## labels, [param hint] its default): the one whose untapping buys most
## this turn — mana the hand still asks for, power that attacks, an
## artifact that works. -1 when the question is not that one, or nothing
## tells the kinds apart.
static func untap_kind(g: MtgGame, pilot, options: Array, hint: int) -> int:
	if not pilot.profile.forecasts_tactics or g.untap_kind_choices.is_empty() \
			or options.size() != g.UNTAP_KINDS.size():
		return -1
	for index in options.size():
		if String(options[index]) != String(g.UNTAP_KIND_LABELS[index]):
			return -1
	var pid: int = pilot.pid
	var me = g.players[pid]
	var open_mana := 0
	var mana_of := {"artifact": 0, "creature": 0, "land": 0}
	var other_of := {"artifact": 0.0, "creature": 0.0, "land": 0.0}
	var their_attack := _attack_power(g, g.opponent_of(pid), null)
	for perm in me.battlefield:
		if perm.phased_out:
			continue
		var made: int = pilot._mana_per_tap(perm.cur_mana_abilities)
		if not perm.tapped:
			open_mana += made
			continue
		if perm.cur_skips_untap or perm.skip_next_untap or perm.skip_untaps > 0:
			continue
		var works := false
		for ability in perm.cur_activated_abilities:
			if ability.tap_cost:
				works = true
		for kind in g._untap_kinds(perm):
			if not mana_of.has(kind):
				continue
			mana_of[kind] = int(mana_of[kind]) + made
			if kind == "creature":
				# It attacks again, and blocks when they have an attack.
				var worth := float(maxi(perm.cur_power, 0))
				if their_attack > 0:
					worth += 1.0
				if works:
					worth += 1.0
				other_of[kind] = float(other_of[kind]) + worth
			elif kind == "artifact" and works and not perm.is_creature():
				other_of[kind] = float(other_of[kind]) + 1.5
	var want := -open_mana
	for card in me.hand:
		if not card.is_land():
			want += card.data.cost.mana_value()
	if pilot._has_ability_wanting_mana(g):
		want += 2
	var best := -1
	var best_score := 0.0
	for index in g.UNTAP_KINDS.size():
		var kind := String(g.UNTAP_KINDS[index])
		var score: float = float(clampi(want, 0, int(mana_of[kind]))) + float(other_of[kind])
		if score > best_score or (score == best_score and score > 0.0 and index == hint):
			best = index
			best_score = score
	return best


## Is the main-phase mistake roll not taken ([method
## AiPlayer._main_phase_action]): a rung that does not price a hand toll,
## its hand over the limit of a squeeze — one card fewer is a point less at
## our next upkeep?
static func fumble_spared(g: MtgGame, pilot) -> bool:
	if not pilot.profile.forecasts_tactics or pilot.profile.minds_the_vise \
			or not g.has_trigger_listener(Mtg.EventType.UPKEEP_START):
		return false
	var size: int = g.players[pilot.pid].hand.size()
	return size > 0 and hand_beat(g, pilot.pid, size, false) > hand_beat(g, pilot.pid, size - 1, false)


## What the main-phase ranking charges [param inst] at a rung that does
## not price a hand toll ([method AiPlayer._try_cast_best]): [constant
## STRETCH_PRICE] a point of damage the smaller hand takes at each of our
## next [constant PUNISH_TURNS] upkeeps. 0.0 with no stretch on the table,
## and at the rungs that mind it.
static func stretch_charge(g: MtgGame, pilot, inst: CardInstance) -> float:
	if not pilot.profile.forecasts_tactics or pilot.profile.minds_the_vise \
			or inst.zone != Mtg.Zone.HAND \
			or not g.has_trigger_listener(Mtg.EventType.UPKEEP_START):
		return 0.0
	var size: int = g.players[pilot.pid].hand.size()
	var more := hand_beat(g, pilot.pid, size - 1, false) - hand_beat(g, pilot.pid, size, false)
	return float(more * PUNISH_TURNS) * STRETCH_PRICE if more > 0 else 0.0


## The mana open to the pilot under a land cap: `[mana, open lands,
## refill]`, or `[]` with no land cap in force.
static func _stock(g: MtgGame, pilot) -> Array:
	var refill := land_refill(g, pilot.pid)
	if refill < 0:
		return []
	var open_lands := 0
	var mana := 0
	for perm in g.players[pilot.pid].battlefield:
		if perm.tapped or perm.phased_out:
			continue
		var made: int = pilot._mana_per_tap(perm.cur_mana_abilities)
		mana += made
		if perm.is_land() and made > 0:
			open_lands += 1
	return [mana, open_lands, refill]


## In our main phase under a land cap: is an activation worth [param
## worth], paid with [param plan], refused — the lands it taps are kept
## for a much better card the stock is about to reach?
static func main_sink_refused(g: MtgGame, pilot, plan: Array, worth: float) -> bool:
	if g.untap_caps.is_empty() or plan.is_empty() or not pilot.profile.forecasts_tactics \
			or worth >= pilot.LETHAL_WORTH:
		return false
	var stock := _stock(g, pilot)
	if stock.is_empty():
		return false
	var spent := 0
	for step in plan:
		var land: CardInstance = step[0]
		if land != null and land.is_land():
			spent += 1
	return spent > 0 and _better_card_waits(g, pilot, null, int(stock[0]), spent,
		int(stock[2]), maxf(worth, 0.0) * STOCK_EDGE)


## Under a land cap: is the X spell [param inst], sized as [param sized]
## ([method SpellTiming.sized_refusal]'s row), refused — the lands its X
## taps are kept for a much better card the stock is about to reach?
static func x_refusal(g: MtgGame, pilot, inst: CardInstance, sized: Dictionary) -> bool:
	if g.untap_caps.is_empty() or not inst.data.cost.has_x:
		return false
	var stock := _stock(g, pilot)
	if stock.is_empty():
		return false
	var cost: ManaCost = inst.data.cost
	var price: int = cost.mana_value() + int(sized.get("x", 0)) * maxi(int(cost.x_count), 1)
	var spent := clampi(price - (int(stock[0]) - int(stock[1])), 0, int(stock[1]))
	return spent > 0 and _better_card_waits(g, pilot, inst, int(stock[0]), spent,
		int(stock[2]), maxf(float(sized.get("value", 0.0)), 0.0) * STOCK_EDGE)
