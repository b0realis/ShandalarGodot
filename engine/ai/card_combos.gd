extends RefCounted
## CARD-COMBOS (2026-10-19, [member AiProfile.plays_combos]) — the pilot's
## knowledge of the loops two or three cards make together, and of how to
## play one.
##
## THE OWNER, after the classic Tempest-era loops were checked against the
## engine: *"lets teach the combos but also strengthen the AI engine to
## discover such things. Lets have a dedicated CARD-COMBOS in AI source code
## that is dedicated to potential card combos and their effective play!"*
##
## WHAT WAS MEASURED FIRST. Every loop below was played by hand through the
## public [MtgGame] API under both rules presets before a line of this file
## existed, and the pilot was then handed the same pieces:
##  * Sliver Queen + Heartstone + Ashnod's Altar — twenty-five rounds by
##    hand, {C} up by twenty-five. The pilot made one Sliver per land a turn
##    and never touched the Altar: [ManaPlanner] skips every mana ability
##    whose cost is a sacrifice, so the round that nets {C} was invisible.
##  * Aluren + Man-o'-War + Soul Warden — twenty free casts by hand, the
##    Man-o'-War returning ITSELF each time, twenty life. The pilot cast the
##    Wall of Blossoms beside it and never the loop.
##  * Corpse Dance + Workhorse + Ashnod's Altar is NOT a loop, whatever a
##    list on the internet says: Corpse Dance with buyback is {4}{B}, the
##    Workhorse and the Altar make only colourless, and the Workhorse's last
##    counter kills it before the Altar can have it (CR 704.3) — five mana a
##    round for a black one from outside. Nor is Wall of Blossoms with one
##    Man-o'-War (two draws, then the Man-o'-War stays on the table), nor a
##    Basalt Monolith alone (tap for three, untap for three).
##
## THREE JOBS, one file:
##  1. KNOW (the catalogue, [constant RECIPES]): the loops of this pool with
##     their pieces. What the catalogue buys is everything that happens
##     BEFORE a loop can run — the pieces cast in an order that assembles
##     one ([method spell_choice]), not discarded or sacrificed for nothing
##     ([method keep_value]), the opponent's pieces priced as the threat they
##     are ([method threat_value], [method counter_threat]) — and a cheap,
##     focused search once every piece is in reach.
##  2. FIND (the search, [method find_loop]): a depth-limited walk over the
##     actions on our own table and in our own hand, run on the search
##     journal ([method MtgGame.make_mark]), looking for a sequence that puts
##     the board back as it was with something gained — mana, a body, life,
##     a card, damage at their face — and nothing lost. Nothing in it is a
##     card name: a loop nobody catalogued is found the same way.
##  3. PLAY ([method main_action]): a loop that was found is run in our own
##     main phase, one engine action per [method AiPlayer.act] like every
##     other action, with a PURPOSE that sets how many rounds ([method
##     _purpose]) and a hard cap ([constant MAX_ROUNDS]). A round that gains
##     nothing for real ends the run.
##
## FAIR PLAY (docs/fair-play.md). The search reads both tables, our own
## hand and the mana pools — nothing else. The opponent's hand is never
## touched; a card the walk DRAWS is never cast by it (it was hidden when
## the walk began), and a library's order is never a reason for anything.
## The journal restores `rng.state`, so a seeded duel replays exactly.
##
## THE BUDGET IS A COUNT, NEVER A CLOCK. [member AiProfile.combo_search_nodes]
## nodes for the open search, [constant FOCUS_NODES] when a catalogued loop
## has every piece in reach; a node is one action tried with the stack
## settled behind it. A clock would make a seeded duel replay differently
## on a slower machine. The search runs only in our own main phase with an
## empty stack, only on a board with something that can repeat ([method
## _motors]), and once per board of loop pieces ([member
## AiPlayer._combo_memo]): about 0.46 ms a node, so a walk that finds
## nothing costs 15 ms at the Sorcerer's 32 nodes and 30 ms at the
## Wizard's 64; every catalogued loop is found within 15.
##
## LIMITS, written down so nobody mistakes them for bugs:
##  * The walk lends itself {C}{C}{C} (never a colour) and the loop must pay
##    the loan back. A loop whose FIRST round needs coloured mana from
##    outside is not found by the open search.
##  * Main phase, our own turn, sorcery-speed timing only — an instant-speed
##    loop at their end step is not run there.
##  * Costs that spend a card from hand, life or the library (Mind Over
##    Matter's discard, a pain land) are not walked: the AI's discard-cost
##    limit (docs/pack-9-tempest-block.md) stands.
##  * One target slot per spell or ability; two-slot ones are not walked.
##  * One run a turn; a run that ends the game needs no second.

## Nodes a CATALOGUED loop's focused search may spend: its pieces are on the
## table or in hand, so the walk is narrow and this is generous.
const FOCUS_NODES := 64
## How deep a walk goes: the longest loop of this pool is three actions
## (Earthcraft's land, the Queen, the tap that untaps the land).
const DEPTH := 3
## The most rounds one run makes, whatever its purpose — each round is two
## or three actions on the duel screen's pace.
const MAX_ROUNDS := 40
## A life loop runs to this much more life, once a turn...
const LIFE_STEP := 20
## ...and never past this total.
const LIFE_CEILING := 60
## The bodies a token loop makes before it stops (a swarm, not a frozen
## screen).
const TOKEN_TARGET := 12
## A draw loop leaves this many cards in the library.
const CARD_FLOOR := 10
## The colourless mana the walk lends itself (see LIMITS above).
const LOAN := 3

## A piece whose cast COMPLETES a loop of ours on the table, on the cast
## ranking's scale ([method AiPlayer._cast_value]) — above a good creature.
const COMPLETE_WORTH := 12.0
## A piece that joins another piece already in reach.
const ADVANCE_WORTH := 3.0
## What a piece of ours is worth keeping beyond its own worth, while
## another piece is in reach ([method keep_value]); twice this once the
## loop is whole.
const KEEP_WORTH := 4.0
## Their piece when two of a loop's pieces are on their table...
const THREAT_NEAR := 5.0
## ...and when every piece that can be seen is.
const THREAT_LIVE := 15.0
## A spell that completes their loop, on the counter bar's scale.
const COUNTER_LIVE := 12.0
## A spell that brings their loop to one piece short.
const COUNTER_NEAR := 6.0

## THE CATALOGUE. Every loop here was proven by hand in the engine and is
## pinned by `tests/ai/test_card_combos.gd` under both rules presets. A slot
## lists the cards that fill it; `loop_slot` names the slot whose card the
## loop CASTS each round from the hand (held there until the rest is on the
## table), -1 when there is none.
const RECIPES := [
	{"name": "Sliver Queen engine", "loop_slot": -1,
		"slots": [["Sliver Queen"], ["Heartstone"], ["Ashnod's Altar"]],
		"gives": "a Sliver for {1}, and {C}{C} for the Sliver: {C} a round"},
	{"name": "Sliver Queen and Pandemonium", "loop_slot": -1,
		"slots": [["Sliver Queen"], ["Ashnod's Altar"], ["Pandemonium"]],
		"gives": "mana-neutral; every Sliver deals 1 as it enters"},
	{"name": "Earthcraft Slivers", "loop_slot": -1,
		"slots": [["Sliver Queen"], ["Heartstone"], ["Earthcraft"]],
		"gives": "a basic land's mana makes a Sliver, the Sliver untaps the land"},
	{"name": "Free Man-o'-War", "loop_slot": 1,
		"slots": [["Aluren"], ["Man-o'-War", "Shrieking Drake"], ["Soul Warden", "Pandemonium"]],
		"gives": "a free creature that returns itself: a life or a damage a round"},
	{"name": "Renewed Thopter", "loop_slot": -1,
		"slots": [["Enduring Renewal"], ["Ornithopter", "Phyrexian Walker", "Shield Sphere"],
			["Ashnod's Altar", "Goblin Bombardment"]],
		"gives": "a free artifact creature sacrificed and returned: {C}{C} or a damage a round"},
	{"name": "Powered Monolith", "loop_slot": -1,
		"slots": [["Basalt Monolith"], ["Power Artifact"]],
		"gives": "tap for {C}{C}{C}, untap for {1}: {C}{C} a round"},
]


# ================================================================ the catalogue --

## Every (recipe, slot) [param card_name] fills, as `{"recipe", "slot"}`.
static func pieces_of(card_name: String) -> Array:
	var out: Array = []
	for recipe in RECIPES:
		var slots: Array = recipe["slots"]
		for i in slots.size():
			if (slots[i] as Array).has(card_name):
				out.append({"recipe": recipe, "slot": i})
	return out


## How [param recipe] stands for [param pid]: per slot, whether a card that
## fills it is on that player's TABLE and — with [param with_hand], for our
## own seat only — in the HAND. [param leave_out] is a card not counted (the
## one whose cast is being priced).
##
## A FACE-DOWN PERMANENT FILLS NO SLOT (bug hunt 2026-10-21): it has no name
## and no abilities (CR 708.2), and on THEIR table the card under it is
## hidden information (CONTRIBUTING.md rule 8). Its printed name was read
## here, so a masked Sliver Queen beside their Heartstone and Altar priced
## the Altar as a live loop's piece and the masked 2/2 as the loop itself.
static func standing(g: MtgGame, pid: int, recipe: Dictionary, with_hand: bool,
		leave_out: CardInstance = null) -> Dictionary:
	var slots: Array = recipe["slots"]
	var on_table: Array[bool] = []
	var in_hand: Array[bool] = []
	for slot in slots:
		var names: Array = slot
		var table := false
		for inst in g.players[pid].battlefield:
			if inst != leave_out and not inst.face_down and names.has(inst.data.card_name):
				table = true
				break
		var held := false
		if with_hand:
			for card in g.players[pid].hand:
				if card != leave_out and names.has(card.data.card_name):
					held = true
					break
		on_table.append(table)
		in_hand.append(held)
	var tabled := 0
	var filled := 0
	for i in slots.size():
		if on_table[i]: tabled += 1
		if on_table[i] or in_hand[i]: filled += 1
	return {"table": on_table, "hand": in_hand, "tabled": tabled, "filled": filled,
		"size": slots.size()}


## The names of every piece of every catalogued loop whose pieces are all
## in reach for [param pid] — on the table, or (ours) in hand. The focused
## search walks only these, the tokens, and the lands when something
## untaps them. Empty when no catalogued loop is whole.
static func assembled_focus(g: MtgGame, pid: int) -> Dictionary:
	var focus: Dictionary = {}
	for recipe in RECIPES:
		var st := standing(g, pid, recipe, true)
		if int(st["filled"]) < int(st["size"]):
			continue
		for slot in recipe["slots"]:
			for card_name in slot:
				focus[card_name] = true
	return focus


## THE CAST (the main-phase ranking, [method AiPlayer._size_and_aim]): a
## piece in hand priced by what it does for a loop of ours, or `null` when
## it is no piece of anything in reach (the generic reading decides).
##  * The card a loop CASTS each round (a Man-o'-War under Aluren) is HELD
##    — `{}` — while the rest of its loop is in reach but not yet on the
##    table: cast now for a bounce, it is not in hand when the loop is ready.
##  * A piece whose cast puts the last missing piece ON THE TABLE (the
##    loop's own cast card may still be in hand) is worth [constant
##    COMPLETE_WORTH] over its own worth; one that joins another piece in
##    reach, [constant ADVANCE_WORTH].
## An Aura piece (Power Artifact) is aimed at the piece it needs; with no
## such piece of ours on the table it is no piece yet.
##
## A SECOND COPY IS NO PROGRESS (review of 2026-10-21, finding ai-5). The
## other slots were measured and the priced card's own never was: a second
## Ashnod's Altar beside the first was priced as advancing the loop, and a
## second Power Artifact as COMPLETING it — aimed at the Monolith the first
## already enchants, where a second reduction does nothing (an untap cost
## of {1} stays {1}), even with a bare Monolith beside it. A piece whose
## slot is already on our table is no piece of that loop; an Aura goes on a
## host that does not wear its name yet ([method _aura_host]) — the start
## of a second loop — or is no piece either.
static func spell_choice(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	if not pilot.profile.plays_combos:
		return null
	var pid: int = pilot.pid
	var best: Variant = null
	var best_value := 0.0
	for piece in pieces_of(inst.data.card_name):
		var recipe: Dictionary = piece["recipe"]
		var slot := int(piece["slot"])
		var st := standing(g, pid, recipe, true, inst)
		var others_filled := 0
		var others_tabled := 0
		var size := int(st["size"])
		for i in size:
			if i == slot:
				continue
			if (st["table"] as Array)[i]: others_tabled += 1
			if (st["table"] as Array)[i] or (st["hand"] as Array)[i]: others_filled += 1
		var loop_slot := int(recipe["loop_slot"])
		if slot == loop_slot:
			# The loop's own cast card waits for the rest to be on the table
			# — unless it already is, when the loop itself casts it.
			if others_filled == size - 1 and others_tabled < size - 1:
				return {}
			continue
		var targets: Array = []
		if inst.data.is_aura():
			var host := _aura_host(g, pid, inst, recipe)
			if host == null:
				continue
			targets = [TargetRef.card(host)]
		elif (st["table"] as Array)[slot]:
			continue   # its slot is filled already: a second copy adds nothing
		# On the table after this cast: every slot but the loop's own cast
		# card, which may wait in hand.
		var needed := size - 1
		var ready := others_tabled
		if loop_slot >= 0 and loop_slot != slot:
			needed -= 1
			if (st["table"] as Array)[loop_slot]:
				ready -= 1
			if not (st["hand"] as Array)[loop_slot]:
				ready = -1   # the card it casts each round is not in hand
		var value := 0.0
		if ready >= needed:
			value = COMPLETE_WORTH
		elif others_filled >= 1:
			value = ADVANCE_WORTH
		else:
			continue
		value += Evaluator.card_value(inst.data)
		if value > best_value:
			best_value = value
			best = {"x": 0, "targets": targets, "value": value}
	return best


## The permanent of ours an Aura piece of [param recipe] goes on: another
## piece of the same loop on our table that the Aura may legally enchant,
## and that does not wear an Aura of this name already (ai-5: that loop is
## whole, and a second copy on it does nothing).
static func _aura_host(g: MtgGame, pid: int, aura: CardInstance, recipe: Dictionary) -> CardInstance:
	var spec: TargetSpec = aura.data.aura_target
	var names: Dictionary = {}
	for slot in recipe["slots"]:
		for card_name in slot:
			names[card_name] = true
	for inst in g.players[pid].battlefield:
		if not names.has(inst.data.card_name) or inst.data.card_name == aura.data.card_name:
			continue
		if spec != null and not spec.is_legal(g, TargetRef.card(inst), aura):
			continue
		if _wears(g, inst, aura.data.card_name):
			continue
		return inst
	return null


## Does [param host] wear an Aura named [param aura_name]?
static func _wears(g: MtgGame, host: CardInstance, aura_name: String) -> bool:
	for id in host.attachments:
		var worn := g.find_instance(int(id))
		if worn != null and worn.zone == Mtg.Zone.BATTLEFIELD and worn.attached_to == host.id \
				and worn.data.card_name == aura_name:
			return true
	return false


## WHAT A PIECE OF OURS IS WORTH KEEPING beyond its own worth — added to
## [method AiPlayer._own_value] (sacrifice fodder, the bodies a cost eats)
## and to the discard ranking ([method AiPlayer.answer_discard]). Nothing
## until another piece of the same loop is in reach; [constant KEEP_WORTH]
## then, twice that once every piece is.
static func keep_value(g: MtgGame, pilot, inst: CardInstance) -> float:
	if not pilot.profile.plays_combos:
		return 0.0
	var worth := 0.0
	for piece in pieces_of(inst.data.card_name):
		var st := standing(g, pilot.pid, piece["recipe"], true)
		if int(st["filled"]) >= int(st["size"]):
			worth = maxf(worth, KEEP_WORTH * 2.0)
		elif int(st["filled"]) >= 2:
			worth = maxf(worth, KEEP_WORTH)
	return worth


## THEIR PIECES (the removal ranking, [method AiPlayer._victim_value]): a
## permanent of [param inst]'s controller priced by the loop it belongs to
## on that player's PUBLIC table. A loop's cast card lives in a hand we may
## not read, so a loop that needs one is never more than near: [constant
## THREAT_LIVE] only when every slot is on their table.
static func threat_value(g: MtgGame, pilot, inst: CardInstance) -> float:
	# A masked permanent is no piece ([method standing]): its name is secret.
	if not pilot.profile.plays_combos or inst.controller_id == pilot.pid or inst.face_down:
		return 0.0
	var worth := 0.0
	for piece in pieces_of(inst.data.card_name):
		var st := standing(g, inst.controller_id, piece["recipe"], false)
		var tabled := int(st["tabled"])
		if tabled >= int(st["size"]):
			worth = maxf(worth, THREAT_LIVE)
		elif tabled >= 2:
			worth = maxf(worth, THREAT_NEAR)
	return worth


## THEIR SPELL (the counter bar, [method AiPlayer._counter_clears_bar]): a
## spell of [param controller]'s that would put the last piece of a loop on
## their table is a threat of [constant COUNTER_LIVE] — above every bar —
## and one that would leave it a piece short, [constant COUNTER_NEAR].
static func counter_threat(g: MtgGame, pilot, spell: CardInstance, controller: int) -> float:
	if not pilot.profile.plays_combos or controller == pilot.pid:
		return 0.0
	var worth := 0.0
	for piece in pieces_of(spell.data.card_name):
		var recipe: Dictionary = piece["recipe"]
		var st := standing(g, controller, recipe, false)
		var slot := int(piece["slot"])
		var after := int(st["tabled"]) + (0 if (st["table"] as Array)[slot] else 1)
		var size := int(st["size"])
		if after >= size:
			worth = maxf(worth, COUNTER_LIVE)
		elif after >= 2 and after >= size - 1:
			worth = maxf(worth, COUNTER_NEAR)
	return worth


# ================================================================== the search --

## The seat the walk answers its own questions with, swapped in for ours
## while it runs. A COST's body is the cheapest thing the loop can spare —
## a token, then a card the walk itself cast, then the least of the rest —
## and, with [member self_first], a choice among our own permanents (the
## Drake's "return a creature you control") takes the card the walk cast.
## It writes down which names it fed to costs and which chose themselves,
## so the real run can steer the same questions ([method steer]).
class LoopSeat extends DecisionAgent:
	var pid := 0
	var self_first := true
	## Instance ids of the cards the walk cast from the hand.
	var cast_ids: Dictionary = {}
	## Names a cost ate during the action being tried.
	var fed: Dictionary = {}
	## Names that answered a question with themselves during the action.
	var chose_self: Dictionary = {}
	## True once [member self_first] changed an answer from the default.
	var steered := false

	func answer_card(game: MtgGame, p_pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		if candidates.is_empty():
			return null
		var asked := current_choice()
		if p_pid != pid:
			return super(game, p_pid, candidates, prompt)
		if asked != null and asked.is_cost:
			var pick := _fodder(candidates)
			fed[pick.data.card_name] = true
			return pick
		if self_first:
			var newest: CardInstance = null
			for c in candidates:
				if cast_ids.has(c.id) and c.zone == Mtg.Zone.BATTLEFIELD \
						and (newest == null or c.layer_timestamp > newest.layer_timestamp):
					newest = c
			if newest != null:
				chose_self[newest.data.card_name] = true
				if newest != candidates[0]:
					steered = true
				return newest
		return super(game, p_pid, candidates, prompt)

	func _fodder(candidates: Array[CardInstance]) -> CardInstance:
		var best: CardInstance = null
		var best_rank := INF
		for c in candidates:
			var rank := float(c.data.cost.mana_value() * 2 + maxi(c.cur_power, 0) + maxi(c.cur_toughness, 0))
			if c.is_token:
				rank -= 1000.0
			elif cast_ids.has(c.id):
				rank -= 500.0
			if rank < best_rank:
				best = c
				best_rank = rank
		return best


## The nodes the last [method find_loop] spent, both walks together — read
## by the budget test and the timing probe, never by a decision.
static var last_nodes := 0


## A search's state, carried down the walk.
class Walk:
	var pid := 0
	var root: Dictionary = {}
	var nodes := 0
	var budget := 0
	var depth := 3
	## Card names the walk may act with (empty = everything of ours).
	var focus: Dictionary = {}
	## The hand when the walk began: the only cards it may cast.
	var root_hand: Dictionary = {}
	## Something on our table untaps a permanent: lands are worth walking.
	var untapper := false
	var seat: LoopSeat = null
	var found: Dictionary = {}


## FIND A LOOP on [param pid]'s side of the board as it stands, or `{}`.
## [param focus]: card names to act with (empty: every card of ours);
## [param budget]: nodes; [param depth]: the longest line tried.
##
## Returns `{"steps": Array[Dictionary], "gains": Dictionary, "fed":
## Dictionary, "chose_self": Dictionary, "float": int}` — the line, what ONE
## round gains (the SECOND round's numbers: the first may still be paying
## the loan back), the names its costs ate, the names that chose
## themselves, and the mana a round spends before it makes any back.
##
## The walk tries the self-first answers first (a card the loop cast
## returns itself — the Man-o'-War); only if those changed some answer and
## found nothing is the default ranking walked as well.
static func find_loop(g: MtgGame, pid: int, focus: Dictionary, budget: int,
		depth := DEPTH) -> Dictionary:
	last_nodes = 0
	if budget <= 0 or g.game_over or not g.stack.is_empty():
		return {}
	var first := _walk(g, pid, focus, budget, depth, true)
	var found: Dictionary = first["found"]
	if not found.is_empty() or not bool(first["steered"]):
		return found
	return _walk(g, pid, focus, maxi(budget / 2, 1), depth, false)["found"]


static func _walk(g: MtgGame, pid: int, focus: Dictionary, budget: int, depth: int,
		self_first: bool) -> Dictionary:
	var walk := Walk.new()
	walk.pid = pid
	walk.budget = budget
	walk.depth = depth
	walk.focus = focus
	var seat := LoopSeat.new()
	seat.pid = pid
	seat.self_first = self_first
	walk.seat = seat
	var foe := g.opponent_of(pid)
	var ours: DecisionAgent = g.agents[pid]
	var theirs: DecisionAgent = g.agents[foe]
	var nested := g.undo_log != null
	var root_mark := g.make_mark()
	g.agents[pid] = seat
	g.agents[foe] = DecisionAgent.new()
	var pick_was: Callable = g.probe_target_pick
	g.probe_target_pick = _self_target.bind(seat)
	g.players[pid].mana_pool.add(Mtg.ManaColor.C, LOAN)
	walk.root = shape(g, pid)
	for card in g.players[pid].hand:
		walk.root_hand[card.id] = true
	walk.untapper = _has_untapper(g, pid, focus)
	# DEEPENING, one action at a time: the SHORTEST loop is the one found.
	# Depth first alone found [Queen, Queen, Altar] — a Sliver a round, but
	# two mana up front — before [Queen, Altar] two levels over.
	for d in range(1, depth + 1):
		walk.depth = d
		_dfs(g, walk, [])
		if not walk.found.is_empty() or walk.nodes >= walk.budget:
			break
	last_nodes += walk.nodes
	g.probe_target_pick = pick_was
	g.agents[pid] = ours
	g.agents[foe] = theirs
	g.unmake_to(root_mark)
	if not nested:
		g.end_search()
	return {"found": walk.found, "steered": seat.steered}


## The walk's answer to a trigger's target in probe mode ([member
## MtgGame.probe_target_pick]): with the self-first answers, a trigger of a
## card the walk cast aims at that card when it may.
static func _self_target(_game: MtgGame, item: StackItem, refs: Array[TargetRef],
		seat: LoopSeat) -> TargetRef:
	if not seat.self_first or item.card == null or not seat.cast_ids.has(item.card.id):
		return null
	for ref in refs:
		if not ref.is_player and ref.instance_id == item.card.id:
			seat.chose_self[item.card.data.card_name] = true
			if ref != refs[0]:
				seat.steered = true
			return ref
	return null


static func _dfs(g: MtgGame, walk: Walk, line: Array) -> void:
	if walk.nodes >= walk.budget or not walk.found.is_empty():
		return
	for action in _actions(g, walk):
		if walk.nodes >= walk.budget or not walk.found.is_empty():
			return
		var mark := g.make_mark()
		walk.nodes += 1
		if _perform(g, walk, action):
			var next := line.duplicate()
			next.append(action)
			var gains := cycle_gains(walk.root, shape(g, walk.pid))
			if not gains.is_empty():
				_confirm(g, walk, next)
			elif next.size() < walk.depth:
				_dfs(g, walk, next)
		g.unmake_to(mark)


## A line that came back round once is played a SECOND time from where it
## ended; only a line that gains again — paying its own way, the walk's
## loan already returned — is a loop. Its second round is what it gains.
static func _confirm(g: MtgGame, walk: Walk, line: Array) -> void:
	var start := shape(g, walk.pid)
	var low := 0
	for action in line:
		if not _perform(g, walk, action):
			return
		low = mini(low, g.players[walk.pid].mana_pool.total() - int(start["pool_total"]))
	var again := cycle_gains(start, shape(g, walk.pid))
	if again.is_empty():
		return
	var fed: Dictionary = {}
	var chose_self: Dictionary = {}
	for action in line:
		fed.merge(action.get("fed", {}))
		chose_self.merge(action.get("chose_self", {}))
	# "float": the mana a round spends before it makes any back — what has to
	# be in reach to START the loop for real (the walk had its loan).
	walk.found = {"steps": line, "gains": again, "fed": fed, "chose_self": chose_self,
		"float": -low}


## THE BOARD'S SHAPE for the loop test: our non-token permanents by name,
## tapped state and counters; our tokens counted; our hand by name; the
## pools; both life totals; their permanent count; our library's size.
static func shape(g: MtgGame, pid: int) -> Dictionary:
	var me := g.players[pid]
	var foe := g.players[g.opponent_of(pid)]
	var perms: Dictionary = {}
	var tokens := 0
	for inst in me.battlefield:
		if inst.is_token:
			tokens += 1
			continue
		var counters: Array = inst.counters.keys()
		counters.sort()
		var counted := ""
		for kind in counters:
			counted += "%s=%d;" % [kind, int(inst.counters[kind])]
		var key := "%s|%s|%s" % [inst.data.card_name, inst.tapped, counted]
		perms[key] = int(perms.get(key, 0)) + 1
	var hand: Dictionary = {}
	for card in me.hand:
		hand[card.data.card_name] = int(hand.get(card.data.card_name, 0)) + 1
	var pool: Dictionary = {}
	for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R,
			Mtg.ManaColor.G, Mtg.ManaColor.C]:
		pool[color] = me.mana_pool.amount_of(color)
	return {"perms": perms, "tokens": tokens, "hand": hand, "hand_size": me.hand.size(),
		"pool": pool, "pool_total": me.mana_pool.total(), "life": me.life,
		"foe_life": foe.life, "foe_perms": foe.battlefield.size(),
		"library": me.library.size()}


## What one round from [param before] to [param after] GAINED, or `{}` when
## it is no round of a loop: our permanents exactly as they were (tapped
## state and counters too), no fewer tokens, every card of the hand still
## there, no less mana in all and no less of any colour, no life lost, no
## life of theirs gained, no card milled beyond the ones drawn — and
## something gained.
static func cycle_gains(before: Dictionary, after: Dictionary) -> Dictionary:
	if not _same_counts(before["perms"], after["perms"]):
		return {}
	var held: Dictionary = before["hand"]
	var now: Dictionary = after["hand"]
	for card_name in held:
		if int(now.get(card_name, 0)) < int(held[card_name]):
			return {}
	var was_pool: Dictionary = before["pool"]
	var is_pool: Dictionary = after["pool"]
	for color in was_pool:
		if int(color) != Mtg.ManaColor.C and int(is_pool.get(color, 0)) < int(was_pool[color]):
			return {}
	if int(after["pool_total"]) < int(before["pool_total"]) \
			or int(after["tokens"]) < int(before["tokens"]) \
			or int(after["life"]) < int(before["life"]) \
			or int(after["foe_life"]) > int(before["foe_life"]) \
			or int(after["foe_perms"]) > int(before["foe_perms"]):
		return {}
	var drawn := int(after["hand_size"]) - int(before["hand_size"])
	if int(before["library"]) - int(after["library"]) > drawn:
		return {}
	var gains := {
		"mana": int(after["pool_total"]) - int(before["pool_total"]),
		"tokens": int(after["tokens"]) - int(before["tokens"]),
		"life": int(after["life"]) - int(before["life"]),
		"damage": int(before["foe_life"]) - int(after["foe_life"]),
		"cards": drawn,
		"removed": int(before["foe_perms"]) - int(after["foe_perms"]),
	}
	for key in gains:
		if int(gains[key]) > 0:
			return gains
	return {}


static func _same_counts(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if int(b.get(key, -1)) != int(a[key]):
			return false
	return true


## Is anything on [param pid]'s table (within [param focus]) able to untap
## a permanent? Then a tap-for-mana is worth walking: the loop may give it
## back.
static func _has_untapper(g: MtgGame, pid: int, focus: Dictionary) -> bool:
	for inst in g.players[pid].battlefield:
		if not focus.is_empty() and not focus.has(inst.data.card_name):
			continue
		for ability in inst.cur_activated_abilities:
			if _untaps(ability):
				return true
	return false


## Does [param a] untap something? Read off the ability's own printed text
## AFTER its cost ("Tap an untapped creature you control: Untap target
## basic land" — the cost's "untapped" is no untap) and never off
## [method EffectBase.describe], which assumes a target that some effects
## (a self-buff's PumpEffect) do not have.
static func _untaps(a: ActivatedAbility) -> bool:
	var text := a.text.to_lower()
	var colon := text.find(":")
	return (text.substr(colon + 1) if colon >= 0 else text).contains("untap")


## An activated ability the walk may try: on the table, no X, no {T} it
## cannot pay, and no cost the walk does not count (a card from the hand,
## life, the library).
static func _ability_tryable(inst: CardInstance, a: ActivatedAbility) -> bool:
	if a.activation_zone != Mtg.Zone.BATTLEFIELD or a.effects.is_empty():
		return false
	if a.cost.has_x or a.only_opponents_may_activate:
		return false
	if a.tap_cost and (inst.tapped or (inst.is_creature() and inst.summoning_sick)):
		return false
	return a.discard_cost == 0 and a.life_cost == 0 and a.library_exile_cost == 0 \
		and a.random_discard_cost == 0 and not a.discard_last_drawn_cost


## The actions the walk tries at this node: each activated and mana
## ability of ours (identical permanents once), each payment row of each
## card of the hand it began with that the pool pays for now — every one
## with the few aims worth trying ([method _aims]).
static func _actions(g: MtgGame, walk: Walk) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pid := walk.pid
	var me := g.players[pid]
	var seen: Dictionary = {}
	for inst in me.battlefield:
		var in_focus := walk.focus.is_empty() or walk.focus.has(inst.data.card_name) or inst.is_token
		if not in_focus and not (inst.is_land() and walk.untapper):
			continue
		for i in inst.cur_activated_abilities.size():
			var a: ActivatedAbility = inst.cur_activated_abilities[i]
			if not _ability_tryable(inst, a):
				continue
			var sig := "a|%s|%d|%s" % [inst.data.card_name, i, inst.tapped]
			if seen.has(sig):
				continue
			seen[sig] = true
			for aim in _aims(g, pid, inst, a.effects):
				out.append({"kind": "ability", "id": inst.id, "card": inst.data.card_name,
					"token": inst.is_token, "index": i, "aim": aim})
		for i in inst.cur_mana_abilities.size():
			var m: ManaAbility = inst.cur_mana_abilities[i]
			if m.taps_source and (inst.tapped or not walk.untapper
					or (inst.is_creature() and inst.summoning_sick)):
				continue
			if m.life_cost > 0 or m.pain > 0:
				continue
			var sig := "m|%s|%d|%s" % [inst.data.card_name, i, inst.tapped]
			if seen.has(sig):
				continue
			seen[sig] = true
			out.append({"kind": "mana", "id": inst.id, "card": inst.data.card_name,
				"token": inst.is_token, "index": i})
	for card in me.hand:
		if not walk.root_hand.has(card.id) or card.is_land():
			continue
		if not walk.focus.is_empty() and not walk.focus.has(card.data.card_name):
			continue
		var sig := "c|%s" % card.data.card_name
		if seen.has(sig):
			continue
		seen[sig] = true
		var rows := g.payment_rows(pid, card)
		for r in rows.size():
			if not _row_payable(g, pid, card, r):
				continue
			var row: Dictionary = rows[r]
			for aim in _aims(g, pid, card, row.get("effects", [])):
				out.append({"kind": "cast", "id": card.id, "card": card.data.card_name,
					"token": false, "row": r, "label": String(row.get("label", "")), "aim": aim})
	return out


## Does the pool pay payment row [param row] of [param card] right now?
static func _row_payable(g: MtgGame, pid: int, card: CardInstance, row: int) -> bool:
	var cost := g.spell_cost_for(pid, card.data, 0, row, card)
	if cost.has_x:
		return false
	return g.players[pid].mana_pool.can_pay(cost, g.spell_surcharge(pid, card.data),
		g.mana_usage_keys(card.data, card))


## The aims worth trying for [param effects] of [param source]: none when
## nothing targets; nothing when two things do (not walked); else up to
## four — their face, the source itself, a tapped permanent of ours (one
## per name: what an untap wants) and their biggest creature — each only
## when legal.
static func _aims(g: MtgGame, pid: int, source: CardInstance, effects: Array) -> Array[Dictionary]:
	var aims: Array[Dictionary] = []
	var spec: TargetSpec = null
	var count := 0
	for e in effects:
		if e.target_spec != null:
			count += 1
			if spec == null:
				spec = e.target_spec
	if count == 0:
		aims.append({"who": "none"})
		return aims
	if count > 1:
		return aims
	var refs := spec.legal_targets(g, source)
	var foe := g.opponent_of(pid)
	var tapped_names: Dictionary = {}
	var biggest: CardInstance = null
	for ref in refs:
		if ref.is_player:
			if ref.player_id == foe and not aims.any(func(a: Dictionary) -> bool: return a["who"] == "foe"):
				aims.append({"who": "foe"})
			continue
		var inst := g.find_instance(ref.instance_id)
		if inst == null:
			continue
		if inst == source:
			aims.append({"who": "self"})
		elif inst.controller_id == pid and inst.tapped and not tapped_names.has(inst.data.card_name):
			tapped_names[inst.data.card_name] = true
			aims.append({"who": "card", "id": inst.id, "card": inst.data.card_name})
		elif inst.controller_id == foe and inst.is_creature() \
				and (biggest == null or inst.cur_power + inst.cur_toughness > biggest.cur_power + biggest.cur_toughness):
			biggest = inst
	if biggest != null:
		aims.append({"who": "their_biggest"})
	return aims


## Try [param action] on the walk's game and settle the stack behind it.
## False when the engine refused it or the game ended (a lethal line is a
## play, not a loop). Writes down what its costs ate and what chose itself.
static func _perform(g: MtgGame, walk: Walk, action: Dictionary) -> bool:
	walk.seat.fed = {}
	walk.seat.chose_self = {}
	# The card is found BEFORE the cast moves it to the stack, and marked
	# before the stack settles — its own arrival trigger asks after it.
	var cast_card: CardInstance = _find(g, walk.pid, action) \
		if String(action["kind"]) == "cast" else null
	var ok := act_out(g, walk.pid, action) != ""
	if ok and cast_card != null:
		walk.seat.cast_ids[cast_card.id] = true
	if ok:
		settle(g)
	action["fed"] = walk.seat.fed.duplicate()
	action["chose_self"] = walk.seat.chose_self.duplicate()
	return ok and not g.game_over


## Pass priority round until the stack is empty — the walk's opponent never
## answers (a search asks what the loop does, not what they would do).
static func settle(g: MtgGame) -> void:
	var guard := 0
	while not g.stack.is_empty() and not g.game_over and guard < 40:
		if g.pass_priority(g.priority_player) != "":
			break
		guard += 1


## Do [param action] for [param pid] through the public engine API, paying
## from the pool as it stands — the caller has tapped for it if it had to.
## "" when it could not be done; otherwise a few words for the log.
static func act_out(g: MtgGame, pid: int, action: Dictionary) -> String:
	var inst := _find(g, pid, action)
	if inst == null:
		return ""
	match String(action["kind"]):
		"mana":
			if g.tap_for_mana(pid, inst, int(action["index"])) != "":
				return ""
		"ability":
			var targets: Variant = _targets(g, pid, inst, action.get("aim", {}))
			if targets == null:
				return ""
			if g.activate_ability(pid, inst, int(action["index"]), targets) != "":
				return ""
		"cast":
			var row := _row_of(g, pid, inst, action)
			var targets: Variant = _targets(g, pid, inst, action.get("aim", {}))
			if row < 0 or targets == null:
				return ""
			if g.cast_spell(pid, inst, targets, 0, row) != "":
				return ""
		_:
			return ""
	return inst.data.card_name


## The object [param action] acts with now: its instance when it is still
## where the action wants it, else (a token made this round, a card back in
## hand under a new id) the first of that name in that zone.
static func _find(g: MtgGame, pid: int, action: Dictionary) -> CardInstance:
	var zone := Mtg.Zone.HAND if String(action["kind"]) == "cast" else Mtg.Zone.BATTLEFIELD
	var inst := g.find_instance(int(action["id"]))
	if inst != null and inst.zone == zone and (inst.controller_id == pid or zone == Mtg.Zone.HAND):
		if zone != Mtg.Zone.BATTLEFIELD or not bool(action.get("token", false)) or not inst.tapped:
			return inst
	var pile: Array[CardInstance] = g.players[pid].hand if zone == Mtg.Zone.HAND \
		else g.players[pid].battlefield
	var fallback: CardInstance = null
	for c in pile:
		if c.data.card_name != String(action["card"]):
			continue
		if zone == Mtg.Zone.BATTLEFIELD and c.tapped:
			if fallback == null:
				fallback = c
			continue
		return c
	return fallback


## The payment row [param action] was found with, by its label when the
## rows have moved since.
static func _row_of(g: MtgGame, pid: int, inst: CardInstance, action: Dictionary) -> int:
	var rows := g.payment_rows(pid, inst)
	var row := int(action.get("row", 0))
	var label := String(action.get("label", ""))
	if row < rows.size() and (label == "" or String((rows[row] as Dictionary).get("label", "")) == label):
		return row
	for i in rows.size():
		if String((rows[i] as Dictionary).get("label", "")) == label:
			return i
	return -1


## The targets an aim names now, or null when it names nothing legal.
static func _targets(g: MtgGame, pid: int, source: CardInstance, aim: Dictionary) -> Variant:
	var foe := g.opponent_of(pid)
	match String(aim.get("who", "none")):
		"none":
			return []
		"foe":
			return [TargetRef.player(foe)]
		"self":
			return [TargetRef.card(source)]
		"card":
			var inst := g.find_instance(int(aim.get("id", -1)))
			if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD or not inst.tapped:
				inst = null
				for c in g.players[pid].battlefield:
					if c.data.card_name == String(aim.get("card", "")) and c.tapped:
						inst = c
						break
			return null if inst == null else [TargetRef.card(inst)]
		"their_biggest":
			var biggest: CardInstance = null
			for c in g.players[foe].battlefield:
				if c.is_creature() and (biggest == null
						or c.cur_power + c.cur_toughness > biggest.cur_power + biggest.cur_toughness):
					biggest = c
			return null if biggest == null else [TargetRef.card(biggest)]
	return null


## THE CHEAP QUESTION BEFORE THE SEARCH: what on our table and in our hand
## can REPEAT, and is any of it a RECYCLER — the thing a loop turns on: a
## mana ability with no {T} (an Altar, a Workhorse's counters), a card the
## pool already pays for (a free row, a {0} cost), an untapper, a token
## maker with no {T}, a sacrifice outlet with no {T}. A pump or a
## regeneration repeats but recycles nothing, and a board of them is not
## searched: the open search runs with a recycler and a second motor, or
## with a free cast, which is a loop's commonest motor.
static func _motors(g: MtgGame, pid: int) -> Dictionary:
	var count := 0
	var recyclers := 0
	var free_cast := false
	for inst in g.players[pid].battlefield:
		for a in inst.cur_activated_abilities:
			if a.tap_cost or not _ability_tryable(inst, a):
				continue
			count += 1
			if a.sacrifice_cost or a.sacrifice_filter.is_valid() or _untaps(a) \
					or a.effects.any(func(e: EffectBase) -> bool: return e is CreateTokenEffect):
				recyclers += 1
		for m in inst.cur_mana_abilities:
			if not m.taps_source:
				count += 1
				recyclers += 1
	for card in g.players[pid].hand:
		if card.is_land():
			continue
		var rows := g.payment_rows(pid, card)
		for r in rows.size():
			var cost := g.spell_cost_for(pid, card.data, 0, r, card)
			if not cost.has_x and cost.mana_value() + g.spell_surcharge(pid, card.data) == 0:
				free_cast = true
				count += 1
				recyclers += 1
				break
	return {"count": count, "recyclers": recyclers, "free_cast": free_cast}


# ===================================================================== the play --

## OUR MAIN PHASE, before the cast ranking ([method AiPlayer._main_phase_action]):
## the next action of a loop being run, or the first of a new one; "" when
## there is none and the pilot plays on as before.
static func main_action(g: MtgGame, pilot) -> String:
	if not pilot.profile.plays_combos:
		return ""
	var run: Dictionary = pilot._combo_run
	if not run.is_empty() and (int(run["turn"]) != g.turn_number
			or int(run["step"]) != g.current_step()):
		run.clear()   # a run never crosses a step
	if run.is_empty() and not _start(g, pilot):
		return ""
	return _advance(g, pilot)


## Is the chain ours and a loop running — then the pilot passes, and the
## round's item resolves (the alternative is the response reading pricing
## our own Sliver ability as something to answer).
static func holds_the_chain(g: MtgGame, pilot) -> bool:
	if not pilot.profile.plays_combos or g.stack.is_empty():
		return false
	var run: Dictionary = pilot._combo_run
	if run.is_empty() or int(run["turn"]) != g.turn_number or int(run["step"]) != g.current_step():
		return false
	return (g.stack.back() as StackItem).controller == pilot.pid


## Look for a loop on this board and, when one is worth running, start it.
static func _start(g: MtgGame, pilot) -> bool:
	var pid: int = pilot.pid
	# ONE RUN A TURN: a loop that ran has done what its purpose asked, and
	# the boards after it are not searched again (each would be a new
	# board to the memo). A lethal run ended the game.
	var spent: Dictionary = pilot._combo_spent
	if int(spent.get("turn", -1)) == g.turn_number:
		return false
	var loop := _loop_here(g, pilot)
	if loop.is_empty():
		return false
	# The opening: the mana a round spends before it pays any back must be
	# in reach now, floating or on an untapped source.
	if g.players[pid].mana_pool.total() + _untapped_mana_sources(g, pid) < int(loop.get("float", 0)):
		return false
	var key := _loop_key(loop)
	var purpose := _purpose(g, pilot, loop)
	if int(purpose["rounds"]) <= 0 and int(purpose.get("sink_count", 0)) <= 0:
		return false
	spent["turn"] = g.turn_number
	var run: Dictionary = pilot._combo_run
	run.clear()
	run.merge({"turn": g.turn_number, "step": g.current_step(), "key": key,
		"steps": loop["steps"], "next": 0, "done": 0, "checked": 0, "rounds": int(purpose["rounds"]),
		"why": String(purpose["why"]), "fed": loop.get("fed", {}),
		"chose_self": loop.get("chose_self", {}), "start": {},
		"sink": purpose.get("sink", {}), "sink_left": int(purpose.get("sink_count", 0)),
		"spare": purpose.get("spare", {})})
	g.log_line("%s goes for a loop: %s" % [g.players[pid].player_name, String(purpose["why"])])
	return true


## The loop this board holds for [param pilot], remembered per board: the
## catalogue's focused search first, then the open one within the
## profile's budget.
static func _loop_here(g: MtgGame, pilot) -> Dictionary:
	var pid: int = pilot.pid
	var memo: Dictionary = pilot._combo_memo
	if int(memo.get("turn", -1)) != g.turn_number:
		memo.clear()
		memo["turn"] = g.turn_number
	var sig := _signature(g, pid)
	if memo.has(sig):
		return memo[sig]
	var loop: Dictionary = {}
	var focus := assembled_focus(g, pid)
	if not focus.is_empty():
		loop = find_loop(g, pid, focus, FOCUS_NODES)
	if loop.is_empty() and int(pilot.profile.combo_search_nodes) > 0:
		var motors := _motors(g, pid)
		if int(motors["recyclers"]) >= 1 \
				and (int(motors["count"]) >= 2 or bool(motors["free_cast"])):
			loop = find_loop(g, pid, {}, int(pilot.profile.combo_search_nodes))
	memo[sig] = loop
	return loop


## One string per board for the memo — and only what a loop can be MADE
## of: the step, our non-land permanents by name and counters, the lands
## when something of ours untaps them, the tokens, the hand's cards (ours
## to know). A land played, a land tapped for a creature, a life lost are
## not a new board to the search: measured 2026-10-19, a walk that finds
## nothing spends its whole budget — 0.46 ms a node, 44 ms at 96 nodes on
## a twelve-permanent table — and keyed by the whole board it ran again
## after every one of them.
static func _signature(g: MtgGame, pid: int) -> String:
	var untapper := _has_untapper(g, pid, {})
	var actors: Array[String] = []
	var tokens := 0
	for inst in g.players[pid].battlefield:
		if inst.is_token:
			tokens += 1
			continue
		if inst.is_land() and not untapper:
			continue
		var counted := ""
		var kinds: Array = inst.counters.keys()
		kinds.sort()
		for kind in kinds:
			counted += "%s=%d;" % [kind, int(inst.counters[kind])]
		actors.append("%s|%s" % [inst.data.card_name, counted])
	actors.sort()
	var hand: Array[String] = []
	for card in g.players[pid].hand:
		hand.append(card.data.card_name)
	hand.sort()
	return "%d|%s|%s|%d" % [g.current_step(), ",".join(PackedStringArray(actors)),
		",".join(PackedStringArray(hand)), tokens]


static func _loop_key(loop: Dictionary) -> String:
	var parts: Array[String] = []
	for step in loop["steps"]:
		parts.append("%s:%s" % [String(step["kind"]), String(step["card"])])
	return ",".join(PackedStringArray(parts))


## WHAT THE LOOP IS RUN FOR, and so how many rounds: `{"rounds", "why"}`,
## plus `"sink"`/`"sink_count"` when the mana is spent by an ability of ours
## the run activates itself. In order, the first that applies:
##  1. DAMAGE AT THEIR FACE each round: to lethal.
##  2. MANA, and an X spell in hand that can hit their face: the mana that
##     makes the X lethal, then the ordinary cast ranking casts it.
##  3. BODIES that stay: [constant TOKEN_TARGET] of them.
##  4. MANA, and a token-making ability with no {T} of ours: the mana for
##     [constant TOKEN_TARGET] bodies, then the run makes them.
##  5. LIFE: [constant LIFE_STEP] more, never past [constant LIFE_CEILING].
##  6. MANA: what the cards in hand the ranking would cast cost beyond the
##     mana already in reach, for the ordinary ranking to spend ([method
##     _mana_for_the_hand]).
##  7. CARDS: to a hand of seven, never under [constant CARD_FLOOR] in the
##     library.
## Every count is capped at [constant MAX_ROUNDS]. Under the 1997 rules the
## mana made is the mana spent (a pool left over burns, CR 500.4 then).
static func _purpose(g: MtgGame, pilot, loop: Dictionary) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var per: Dictionary = loop["gains"]
	var me := g.players[pid]
	var their_life := g.players[foe].life
	var mana := int(per.get("mana", 0))
	var in_reach := me.mana_pool.total() + _untapped_mana_sources(g, pid)
	if int(per.get("damage", 0)) > 0:
		return {"rounds": mini(_ceil_div(their_life, int(per["damage"])), MAX_ROUNDS),
			"why": "damage to lethal"}
	if mana > 0:
		var burn := _lethal_x(g, pid, their_life)
		if not burn.is_empty():
			var rounds := _ceil_div(maxi(0, int(burn["need"]) - in_reach), mana)
			if rounds <= MAX_ROUNDS:
				# The lands the X spell's coloured pips need are never tapped
				# for the loop's opening mana: a lone Mountain is the Fireball.
				return {"rounds": maxi(rounds, 1), "why": "mana for a lethal X",
					"spare": _spare_for(g, pid, burn["card"])}
	var bodies := _token_count(g, pid)
	if int(per.get("tokens", 0)) > 0 and bodies < TOKEN_TARGET:
		return {"rounds": mini(_ceil_div(TOKEN_TARGET - bodies, int(per["tokens"])), MAX_ROUNDS),
			"why": "a swarm"}
	if mana > 0 and bodies < TOKEN_TARGET:
		var sink := _token_sink(g, pid)
		if not sink.is_empty():
			var want := TOKEN_TARGET - bodies
			var cost := int(sink["cost"])
			# The lands in reach pay for the first rounds and the last
			# bodies, so the mana made is the mana spent.
			var rounds := mini(_ceil_div(maxi(0, want * cost - in_reach), mana), MAX_ROUNDS)
			var affordable := (in_reach + rounds * mana) / maxi(cost, 1)
			return {"rounds": rounds, "why": "mana for a swarm", "sink": sink["step"],
				"sink_count": mini(want, affordable)}
	if int(per.get("life", 0)) > 0 and me.life < LIFE_CEILING:
		var target := mini(me.life + LIFE_STEP, LIFE_CEILING)
		return {"rounds": mini(_ceil_div(target - me.life, int(per["life"])), MAX_ROUNDS),
			"why": "life"}
	if mana > 0:
		var hand := _mana_for_the_hand(g, pilot, loop, in_reach)
		if int(hand["rounds"]) > 0:
			return {"rounds": int(hand["rounds"]), "why": "mana for the hand",
				"spare": hand["spare"]}
	if int(per.get("cards", 0)) > 0:
		var room := mini(7 - me.hand.size(), me.library.size() - CARD_FLOOR)
		if room > 0:
			return {"rounds": mini(_ceil_div(room, int(per["cards"])), MAX_ROUNDS), "why": "cards"}
	return {"rounds": 0, "why": ""}


## THE HAND THE MANA IS FOR (review of 2026-10-21, finding ai-1) —
## `{"rounds", "spare"}`, no rounds when nothing in hand is worth one.
##
## Purpose 6 summed the mana value of every card in hand that is no loop
## piece and asked nothing else of it: three Counterspells held for a
## response, a Serra Angel with no white source, a card a cast gate
## refuses. The loop made the mana, nothing spent it, and it burned — a
## Wizard with Enduring Renewal, Ashnod's Altar and an Ornithopter cast
## the Ornithopter four times for three Counterspells and lost 6 life, and
## a Power Artifact deck in the Deck Lab burned 3, twice. The doc above
## [method _purpose] already said the mana made is the mana spent; now the
## code does. The cards counted are the ones the main-phase ranking would
## cast with the loop's {C} added to our sources ([method _hand_casts]).
##
## UNDER MANA BURN the loop's {C} pays only generic costs, so a run makes
## no more {C} — its opening included ("float", the mana a round spends
## before it pays any back, which a land paid) — than the generic of the
## cards it is for. Two {C} a round and a three-mana card with no land is
## no run at all: two rounds leave one {C} to burn and one round is short.
## Of the cards in hand, the set that spends the most with nothing left
## over is what the run is sized for (fewer rounds on a tie); without mana
## burn the whole hand is, as before.
static func _mana_for_the_hand(g: MtgGame, pilot, loop: Dictionary, in_reach: int) -> Dictionary:
	var pid: int = pilot.pid
	var mana := int((loop["gains"] as Dictionary).get("mana", 0))
	var none := {"rounds": 0, "spare": {}}
	var cards := _hand_casts(g, pilot)
	if mana <= 0 or cards.is_empty():
		return none
	var chosen: Array = []
	var rounds := 0
	if not g.rules.mana_burn:
		var total := 0
		for row in cards:
			total += int(row["total"])
		rounds = mini(_ceil_div(maxi(0, total - in_reach), mana), MAX_ROUNDS)
		chosen = cards
	else:
		var opening := int(loop.get("float", 0))
		var n := mini(cards.size(), HAND_PLAN_CARDS)
		var best_total := 0
		var best_mask := 0
		for mask in range(1, 1 << n):
			var total := 0
			var generic := 0
			for i in n:
				if mask & (1 << i):
					total += int(cards[i]["total"])
					generic += int(cards[i]["generic"])
			var need := _ceil_div(maxi(0, total - in_reach), mana)
			if need <= 0 or need > MAX_ROUNDS or need * mana + opening > generic:
				continue
			if total > best_total or (total == best_total and need < rounds):
				best_total = total
				best_mask = mask
				rounds = need
		for i in n:
			if best_mask & (1 << i):
				chosen.append(cards[i])
	if rounds <= 0:
		return none
	# The lands the chosen cards' coloured pips need are never tapped for
	# the loop's opening mana (the lethal X's own rule, [method _spare_for]).
	var spared: Dictionary = {}
	for row in chosen:
		_spare_into(g, pid, row["card"], spared)
	return {"rounds": rounds, "spare": spared}


## The most cards of the hand [method _mana_for_the_hand] weighs together
## under mana burn — every subset of them, 255 at most.
const HAND_PLAN_CARDS := 8
## The unit numbers of the loop's {C} lent to the ranking's own question in
## [method _hand_casts] — clear of the pool's own rows.
const LOOP_UNIT_BASE := 7000


## The cards in our hand the main-phase ranking would CAST with the loop's
## {C} beside our own sources, as `{"card", "total", "generic"}` — total
## mana and the part of it colourless mana pays. The question is the
## ranking's own, asked the way [method AiPlayer._ritual_has_a_use] asks it
## of a Dark Ritual's mana: past every gate the ranking keeps ([method
## AiPlayer._ranking_gates_refuse] — a Counterspell held for a response,
## a hand lock, a second legend), aimed at something worth it ([method
## AiPlayer._size_and_aim], [method MtgGame.cast_refusal]), not one it
## would wait on ([method AiPlayer._ranking_would_wait]) — and with the
## coloured pips of every card counted so far paid by our own sources, all
## of them together: the loop makes no colour. A loop piece is the run's
## own business, a free card needs no mana and an X spell's X is not
## guessed at (the lethal one is purpose 2).
static func _hand_casts(g: MtgGame, pilot) -> Array:
	var pid: int = pilot.pid
	var rows: Array = pilot._mana_sources(g)
	var lent: Array = rows.duplicate()
	var room := 0
	for card in g.players[pid].hand:
		room += card.data.cost.mana_value() + maxi(g.spell_surcharge(pid, card.data), 0)
	for unit in room:
		lent.append([null, LOOP_UNIT_BASE + unit, Mtg.ManaColor.C, 1, 0, "", 0, 0])
	var pips := ManaCost.new()
	var out: Array = []
	for card in g.players[pid].hand:
		if card.is_land() or card.data.cost.has_x or not pieces_of(card.data.card_name).is_empty():
			continue
		if pilot._ranking_gates_refuse(g, card):
			continue
		var extra: int = g.spell_surcharge(pid, card.data)
		var total: int = card.data.cost.mana_value() + extra
		if total <= 0:
			continue
		var keys: Array = g.mana_usage_keys(card.data, card)
		if (pilot._plan_taps_from(lent, card.data.cost, extra, keys) as Array).is_empty():
			continue
		var mode: int = pilot._pick_mode(g, card.data)
		var choice: Dictionary = pilot._size_and_aim(g, card, pilot._mode_intent(card.data, mode), 0, mode)
		if choice.is_empty() or float(choice.get("value", 0.0)) <= 0.0:
			continue
		if g.cast_refusal(pid, card, choice.get("targets", []), 0, mode) != "":
			continue
		if pilot._ranking_would_wait(g, card, choice, mode, lent):
			continue
		var with_it := _pips_with(pips, card.data.cost)
		if not with_it.colored.is_empty() \
				and (pilot._plan_taps_from(rows, with_it, 0) as Array).is_empty():
			continue   # no source of its colour left over for it
		pips = with_it
		var coloured := 0
		for color in card.data.cost.colored:
			if int(color) != Mtg.ManaColor.C:
				coloured += int(card.data.cost.colored[color])
		out.append({"card": card, "total": total, "generic": maxi(total - coloured, 0)})
	return out


## [param pips] with [param cost]'s coloured pips added — {C} left out, the
## loop's own mana pays it — and no generic: what our sources must pay.
static func _pips_with(pips: ManaCost, cost: ManaCost) -> ManaCost:
	var out := ManaCost.new()
	out.colored = pips.colored.duplicate()
	out.text = pips.text + cost.text
	for color in cost.colored:
		if int(color) != Mtg.ManaColor.C:
			out.colored[color] = int(out.colored.get(color, 0)) + int(cost.colored[color])
	return out


static func _ceil_div(a: int, b: int) -> int:
	return 0 if b <= 0 else (a + b - 1) / b


static func _token_count(g: MtgGame, pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_token:
			n += 1
	return n


static func _untapped_mana_sources(g: MtgGame, pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.tapped or (inst.is_creature() and inst.summoning_sick):
			continue
		for m in inst.cur_mana_abilities:
			if m.taps_source and not m.sacrifice_filter.is_valid():
				n += 1
				break
	return n


## The X spell of our hand that deals [param their_life] at their face for
## the least mana — `{"card", "need"}`, its own cost plus X — or `{}`.
static func _lethal_x(g: MtgGame, pid: int, their_life: int) -> Dictionary:
	var best: Dictionary = {}
	for card in g.players[pid].hand:
		if not card.data.cost.has_x:
			continue
		var intent := EffectIntent.read(card.data.spell_effects, card.data.card_name)
		if not intent.damage_uses_x or intent.target_spec == null:
			continue
		if not intent.target_spec.is_legal(g, TargetRef.player(g.opponent_of(pid)), card):
			continue
		var need := card.data.cost.mana_value() + their_life * maxi(card.data.cost.x_count, 1)
		if best.is_empty() or need < int(best["need"]):
			best = {"card": card, "need": need}
	return best


## Our untapped sources that make [param card]'s coloured pips, one per
## pip, as the `spared` set [method AiPlayer._plan_and_pay] leaves alone.
static func _spare_for(g: MtgGame, pid: int, card: CardInstance) -> Dictionary:
	return _spare_into(g, pid, card, {})


## [method _spare_for] added to [param spared] — a source already spared
## for an earlier card is not counted twice.
static func _spare_into(g: MtgGame, pid: int, card: CardInstance, spared: Dictionary) -> Dictionary:
	for color in card.data.cost.colored:
		var wanted := int(card.data.cost.colored[color])
		for inst in g.players[pid].battlefield:
			if wanted <= 0:
				break
			if inst.tapped or spared.has(inst.id) or (inst.is_creature() and inst.summoning_sick):
				continue
			for m in inst.cur_mana_abilities:
				if m.taps_source and m.produces.any(func(pair: Array) -> bool: return int(pair[0]) == int(color)):
					spared[inst.id] = true
					wanted -= 1
					break
	return spared


## A token-making ability of ours with no {T} that the loop's mana can pay
## (Sliver Queen): `{"step", "cost"}`, or `{}`.
static func _token_sink(g: MtgGame, pid: int) -> Dictionary:
	for inst in g.players[pid].battlefield:
		for i in inst.cur_activated_abilities.size():
			var a: ActivatedAbility = inst.cur_activated_abilities[i]
			if a.tap_cost or not _ability_tryable(inst, a):
				continue
			if not a.effects.any(func(e: EffectBase) -> bool: return e is CreateTokenEffect):
				continue
			if a.sacrifice_cost or a.sacrifice_filter.is_valid() or not a.object_costs.is_empty():
				continue
			var payment := g.ability_payment(pid, inst, i, 0)
			var cost: ManaCost = payment["cost"]
			if not cost.colored.is_empty():
				continue   # the loop makes colourless
			return {"step": {"kind": "ability", "id": inst.id, "card": inst.data.card_name,
				"token": false, "index": i, "aim": {"who": "none"}},
				"cost": cost.mana_value() + int(payment["extra"])}
	return {}


## One action of the run. A new round first asks whether the LAST round
## gained for real (from the second round on: the first may have tapped a
## land for the loop's opening mana); a round that gained nothing, or a step
## the engine refuses, ends the run.
static func _advance(g: MtgGame, pilot) -> String:
	var run: Dictionary = pilot._combo_run
	var pid: int = pilot.pid
	var steps: Array = run["steps"]
	# ONCE per finished round — never again during the sink, whose bodies
	# are bought with the pool the rounds made.
	if int(run["next"]) == 0 and int(run["checked"]) != int(run["done"]):
		run["checked"] = int(run["done"])
		if int(run["done"]) >= 2 and cycle_gains(run["start"], shape(g, pid)).is_empty():
			return _stop(g, pilot, "a round gained nothing")
		run["start"] = shape(g, pid)
	if int(run["done"]) >= int(run["rounds"]):
		if int(run["sink_left"]) > 0:
			run["sink_left"] = int(run["sink_left"]) - 1
			var made := _pay_and_act(g, pilot, run["sink"])
			if made == "":
				return _stop(g, pilot, "the sink refused")
			return "made a token with %s" % made
		run.clear()
		return ""
	var step: Dictionary = steps[int(run["next"])]
	# A TAP ALREADY MADE. The pilot's own tap plan may have paid an earlier
	# step of the round with this very source (Earthcraft's line: the
	# Queen's {1} came off the Forest the loop taps next) — its mana is
	# spent where the loop would have spent it, and the step is done.
	if _already_tapped(g, pid, step) and int(run["next"]) + 1 < steps.size():
		run["next"] = int(run["next"]) + 1
		step = steps[int(run["next"])]
	var did := _pay_and_act(g, pilot, step)
	if did == "":
		return _stop(g, pilot, "%s refused" % String(step["card"]))
	run["next"] = int(run["next"]) + 1
	if int(run["next"]) >= steps.size():
		run["next"] = 0
		run["done"] = int(run["done"]) + 1
	return "loop (%d of %d): %s" % [mini(int(run["done"]) + 1, int(run["rounds"])),
		int(run["rounds"]), did]


## Is [param step] a {T} mana ability whose source is tapped already?
static func _already_tapped(g: MtgGame, pid: int, step: Dictionary) -> bool:
	if String(step["kind"]) != "mana":
		return false
	var inst := _find(g, pid, step)
	if inst == null or not inst.tapped:
		return false
	var index := int(step["index"])
	return index < inst.cur_mana_abilities.size() and inst.cur_mana_abilities[index].taps_source


static func _stop(g: MtgGame, pilot, why: String) -> String:
	g.log_line("(AI loop stopped: %s)" % why)
	(pilot._combo_run as Dictionary).clear()
	return ""


## Pay for [param step] the way the pilot pays for anything — the pool
## first, then its own tap plan ([method AiPlayer._plan_and_pay]) — and do
## it. A mana ability pays for itself.
static func _pay_and_act(g: MtgGame, pilot, step: Dictionary) -> String:
	var pid: int = pilot.pid
	var inst := _find(g, pid, step)
	if inst == null:
		return ""
	var pool := g.players[pid].mana_pool
	var spare: Dictionary = (pilot._combo_run as Dictionary).get("spare", {})
	match String(step["kind"]):
		"ability":
			var payment := g.ability_payment(pid, inst, int(step["index"]), 0)
			var cost: ManaCost = payment["cost"]
			var extra := int(payment["extra"])
			var usage: Array = payment["usage"]
			if not pool.can_pay(cost, extra, usage) \
					and not pilot._plan_and_pay(g, cost, extra, usage, spare):
				return ""
		"cast":
			var row := _row_of(g, pid, inst, step)
			if row < 0:
				return ""
			var targets: Variant = _targets(g, pid, inst, step.get("aim", {}))
			if targets == null or g.cast_refusal(pid, inst, targets, 0, row) != "":
				return ""
			var cost := g.spell_cost_for(pid, inst.data, 0, row, inst)
			var extra := g.spell_surcharge(pid, inst.data)
			var usage := g.mana_usage_keys(inst.data, inst)
			if not pool.can_pay(cost, extra, usage) \
					and not pilot._plan_and_pay(g, cost, extra, usage, spare):
				return ""
	return act_out(g, pid, step)


## THE RUN'S OWN QUESTIONS, asked of [method AiPlayer.answer_card] while a
## loop runs: a cost's body is the one the walk fed it (a Sliver token, the
## Ornithopter), and a card that chose itself in the walk chooses itself
## again (the newest of that name). Null: the pilot's own answer.
static func steer(g: MtgGame, pilot, candidates: Array[CardInstance], asked: PlayerChoice) -> CardInstance:
	var run: Dictionary = pilot._combo_run
	if run.is_empty() or asked == null or candidates.is_empty():
		return null
	if int(run["turn"]) != g.turn_number or int(run["step"]) != g.current_step():
		return null
	if asked.is_cost:
		var fed: Dictionary = run["fed"]
		var pick: CardInstance = null
		for c in candidates:
			if not fed.has(c.data.card_name):
				continue
			if pick == null or (c.is_token and not pick.is_token) \
					or (c.is_token == pick.is_token and c.layer_timestamp > pick.layer_timestamp):
				pick = c
		return pick
	if not (run["chose_self"] as Dictionary).has(asked.source):
		return null
	var newest: CardInstance = null
	for c in candidates:
		if c.data.card_name == asked.source and c.controller_id == pilot.pid \
				and (newest == null or c.layer_timestamp > newest.layer_timestamp):
			newest = c
	return newest
