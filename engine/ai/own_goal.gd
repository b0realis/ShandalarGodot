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
##    costs our last life. Its own section, at the end of this file.
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

static var _arrival_burn: RegEx = null
static var _upkeep_wrath: RegEx = null


## Why [param inst], a card in the pilot's hand, is not cast in this
## position ("" when nothing here objects) — [method AiPlayer._cast_gate]'s
## last question.
static func cast_refusal(g: MtgGame, pilot, inst: CardInstance) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	var data: CardData = inst.data
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
# THE RULE ([method AiPlayer._land_toll_refuses]): a drop that costs our
# last life is never made; one that costs [constant TOLL_SHARE]'s part of
# our life or more is made only for a land that unlocks a cast this turn;
# a lighter one is the price of the land and is paid as before.

## A toll of life / TOLL_SHARE or more is a heavy one.
const TOLL_SHARE := 4
## The answer for a drop that ends the game against us.
const TOLL_LETHAL := 1000000

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
