extends RefCounted
## THE MOMENT A SPELL IS WORTH ITS CARD (player report 2026-11-26: "casts
## Sandstorm outside of combat", "casts Hurkyl's Recall when you have no
## artifacts", "casts Stream of Life turn 2 for one life gain"). An instant
## or a sorcery is a card spent; this module is the pilot asking what the
## cast would actually DO before it spends one. No card is named: every
## reading is the card's printed text, its effects, the public board, and a
## forecast — the cast itself run under the search journal with nobody
## asked and everything put back.
##
##  * THE COMBAT IT NEEDS ("… each attacking creature", "Blocking creatures
##    get …", "Prevent all combat damage that would be dealt this turn"): a
##    spell whose printed effect only touches attacking or blocking
##    creatures, or combat damage, is not cast while no creature attacks
##    (none blocks). [method cast_refusal].
##  * … AND IS CAST IN IT WHEN IT PAYS ([method respond]): once attackers
##    are declared, an untargeted spell of that shape is forecast — at once,
##    and through the declared combat when the blocks are known — and cast
##    when the board it leaves is better by about a card
##    ([constant CARD_BAR]) or it saves the game.
##  * THE CAST THAT CHANGES NOTHING ("Tap all blue creatures" with none on
##    the table, "Return all … target player owns" at a player who owns
##    none, a shield with nothing to stop): the forecast found no difference
##    but the card spent. [method sized_refusal].
##  * THE SET THAT IS NOT WORTH A CARD ("all …", "each …" over permanents):
##    what each side loses is counted off the forecast, and the cast waits
##    below [constant CARD_BAR].
##  * THE X THAT IS TOO SMALL ("Target player gains X life" for one): a
##    spell that only scales with its X is held under [method x_floor]
##    unless it wins, saves the game, or the card would be discarded.
##
##  * THE TRICK NOBODY READ ("Target creature gets +0/+X …", "… it gets
##    +4/-4 …" from a card-local effect): the printed line says it is a
##    gift, so it is aimed at our own side ([method trick_of], asked by
##    [method AiPlayer._is_harmful]); a pilot that holds instants keeps it
##    for a combat and casts it on the creature in that combat where the
##    declared fight ends about a card better ([method respond]).
##  * THE DAMAGE OF THIS TURN ("… equal to the damage dealt to you this
##    turn", "… twice the damage dealt to you so far this turn by
##    artifacts"): held while that damage is none ([method cast_refusal]),
##    cast at an end step once it is worth the card ([method respond]).
##  * THE LIFE NOT NEEDED: an X of nothing but our own life waits while
##    the pilot stands at its starting life or above, out of danger.
##  * THE PILOT THAT HOLDS NO INSTANT ([member AiProfile.holds_instants]
##    off) still casts a spell whose only moment is a combat in that
##    combat, by the same forecast ([method respond], asked by
##    [method AiPlayer.act]) — and nothing else at instant speed.
##
##  * THE GUARD AND THE SWITCH (0.70.15: "If a spell or ability that
##    targets that creature would cause a source to deal damage to it …,
##    prevent that damage", "When that creature dies this turn, return a
##    creature card …", "Switch target creature's power and toughness
##    until end of turn"; [method guard_of]): a shield and an insurance
##    belong on our own creature ([method aims_home]) and none of the three
##    is a main-phase card. Each is cast by this module alone: in answer to
##    a spell or ability of theirs that names a creature of ours, when the
##    stack resolved with it leaves us about a card better
##    ([method _respond_stack]); in a declared combat, blocks known, on the
##    creature where the fight ends about a card better (a switch on either
##    side's); and a switch in our own main phase only at a creature across
##    the table it kills (power 0 becomes toughness 0).
##
## All of it behind [member AiProfile.forecasts_tactics], which every
## standard rung ships on: the gate off is the pilot as it was. A hand with
## no instant or sorcery in it asks nothing here.

## What a cast must be worth before it is a card well spent: the pilot's
## own price of a card in hand ([member AiProfile.w_hand]'s default).
const CARD_BAR := 1.5
## A forecast that ends the game.
const GAME := 1000.0
## The X a spell that only scales with X is held for.
const X_FLOOR := 4
## A hand this full discards at cleanup: the card goes now.
const HAND_FULL := 7
## The most creatures in a combat one aimed spell is forecast on.
const AIM_CAP := 8
## [method guard_of]'s kinds.
const GUARD_SHIELD := 1
const GUARD_INSURANCE := 2
const GUARD_SWITCH := 3
## Set on the pilot while this module asks its gate about a card it casts
## itself ([method cast_refusal] lets the guard shapes through for it alone).
const _OPEN := &"spell_timing_open"

const _COLORS := [1, 2, 4, 8, 16, 32]

## What a card's printed text asks of the table (a row per card name).
static var _shapes: Dictionary = {}
static var _lock := Mutex.new()
static var _rx: Dictionary = {}

## The journal's bookkeeping: properties every cast writes, whatever it
## does. A forecast that touched nothing else changed nothing.
const _GAME_NOISE: Array[StringName] = [
	&"agents", &"_probing", &"_probe_information", &"priority_player", &"_passes",
	&"_next_stack_id", &"spells_cast_this_turn", &"loop_steps", &"_damage_event_serial",
	&"_damage_event_item", &"_next_packet_id", &"choice_history", &"stack",
]
const _OTHER_NOISE: Array[StringName] = [&"acted_this_turn", &"_timestamp"]


# ------------------------------------------------------------ the reading --

## The printed text an effect reading works on: lower case, reminder text
## (the parentheses) taken out, "nonattacking"/"nonblocking" set aside so
## they never read as their opposite.
static func plain(text: String) -> String:
	var lower := text.to_lower()
	var out := ""
	var depth := 0
	for i in lower.length():
		var ch := lower[i]
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth = maxi(depth - 1, 0)
		elif depth == 0:
			out += ch
	return out.replace("nonattacking", "idle").replace("nonblocking", "idle")


static func _regex(key: String, pattern: String) -> RegEx:
	var rx: RegEx = _rx.get(key)
	if rx == null:
		rx = RegEx.create_from_string(pattern)
		_rx[key] = rx
	return rx


## The shape of [param data], read once per card: [code]attack[/code] — its
## effect needs attacking creatures; [code]block[/code] — it needs blocks;
## [code]combat[/code] — it only prevents or changes combat damage;
## [code]hidden[/code] — its outcome depends on a hidden zone or on chance,
## or it makes mana (the forecast lends mana and cannot see it), so no
## forecast is made of it; [code]set[/code] — its effect is over a
## set of permanents ("all", "each"); [code]choice[/code] — it offers
## modes ("Choose one —"); [code]trick[/code] — [method trick_of];
## [code]tally[/code] — it counts the damage dealt to its caster this turn
## (1), by artifacts only (2); [code]guard[/code] — [method guard_of], and
## [code]sole[/code] — nobody else reads that guard, so this module alone
## casts it.
static func shape_of(data: CardData) -> Dictionary:
	_lock.lock()
	var shape: Variant = _shapes.get(data.card_name)
	if shape == null:
		shape = _read_shape(plain(data.oracle_text))
		if int(shape["trick"]) != 0 and not _unread_aimed(data):
			shape["trick"] = 0
		if not _one_aimed(data):
			shape["guard"] = 0
		elif data.spell_effects[0] is SwitchPowerToughnessEffect:
			shape["guard"] = GUARD_SWITCH
		if int(shape["guard"]) != 0:
			var read: EffectIntent = EffectIntent.read(data.spell_effects, data.card_name)
			shape["sole"] = read.unknown and read.window == EffectIntent.Shape.NONE
		_shapes[data.card_name] = shape
	_lock.unlock()
	return shape


## The trick the effect reader has no model for, by its printed line: 1 — a
## gift ("Target creature gets +0/+X until end of turn"), nothing taken; 2 —
## power given and toughness taken ("… it gets +4/-4 until end of turn"),
## which the fight it is cast into has to answer for; 0 — anything else,
## and every spell the reader does read (a Giant Growth is its own).
static func trick_of(data: CardData) -> int:
	if data.is_permanent_type() or data.oracle_text.is_empty():
		return 0
	return int(shape_of(data)["trick"])


## A guard for one creature, for this turn, by the printed line of a spell
## with one effect aimed at one creature: [constant GUARD_SHIELD] — damage
## to it is prevented ("Prevent all damage that would be dealt to target
## creature this turn", "If a spell or ability that targets that creature
## would cause a source to deal damage to that creature this turn, prevent
## that damage"); [constant GUARD_INSURANCE] — its death this turn brings a
## creature back ("When that creature dies this turn, return a creature
## card from its owner's graveyard to the battlefield …");
## [constant GUARD_SWITCH] — its power and toughness are switched until end
## of turn; 0 — none of them.
static func guard_of(data: CardData) -> int:
	if data.is_permanent_type() or data.oracle_text.is_empty():
		return 0
	return int(shape_of(data)["guard"])


## Does the printed line put this spell on our own side of the table — the
## gift nobody read ([method trick_of]), the shield, the insurance? Asked by
## [method AiPlayer._is_harmful].
static func aims_home(data: CardData) -> bool:
	if data.is_permanent_type() or data.oracle_text.is_empty():
		return false
	var shape := shape_of(data)
	var guard := int(shape["guard"])
	return int(shape["trick"]) != 0 or guard == GUARD_SHIELD or guard == GUARD_INSURANCE


## A plain spell of one effect aimed at one creature: no modes, no X, no
## condition on its cast.
static func _one_aimed(data: CardData) -> bool:
	if data.is_permanent_type() or data.is_modal() or data.cost.has_x \
			or data.cast_condition.is_valid() or data.spell_effects.size() != 1:
		return false
	var e: EffectBase = data.spell_effects[0]
	return e.target_spec != null and e.target_spec.kind == TargetSpec.Kind.CREATURE \
		and not e.target_count_is_x


## [method guard_of]'s reading of a printed text (already [method plain]).
static func _read_guard(text: String) -> int:
	if _regex("switch", "switch target( [a-z-]+){0,3} creature's power and toughness until end of turn").search(text) != null:
		return GUARD_SWITCH
	if _regex("insure", "(when|if) (that|target|the) creature (dies|would die|is put into (a|the|its owner's) graveyard)( from the battlefield)? this turn, (you may )?(return|put)").search(text) != null:
		return GUARD_INSURANCE
	for sentence in text.replace("\n", ". ").split(". "):
		if sentence.contains("prevent") and sentence.contains("damage") \
				and sentence.contains("this turn") \
				and not sentence.contains("combat damage") and not sentence.contains("dealt by") \
				and _regex("shield", "to (that|target)( [a-z-]+){0,3} creature").search(sentence) != null:
			return GUARD_SHIELD
	return 0


## One card-local effect, aimed at a creature, that the reader calls
## unknown and no window, rider or helper already speaks for.
static func _unread_aimed(data: CardData) -> bool:
	if data.is_permanent_type() or data.is_modal() or data.cost.has_x \
			or data.cast_condition.is_valid() or data.spell_effects.size() != 1:
		return false
	var e: EffectBase = data.spell_effects[0]
	if e.target_spec == null or e.target_spec.kind != TargetSpec.Kind.CREATURE \
			or e.ai_helpful or e.is_damage_prevention or e.target_count_is_x:
		return false
	var intent: EffectIntent = EffectIntent.read(data.spell_effects, data.card_name)
	return intent.unknown and intent.window == EffectIntent.Shape.NONE


## [method trick_of]'s reading of a printed text (already [method plain]).
static func _read_trick(text: String) -> int:
	var found := _regex("trick", "target( [a-z-]+){0,3} creature[^.]*?\\bgets? ([+-])(\\d+|x)/([+-])(\\d+|x) until end of (turn|combat)").search(text)
	if found == null:
		return 0
	var power_given := found.get_string(3) != "0"
	var toughness_given := found.get_string(5) != "0"
	if power_given and found.get_string(2) == "-":
		return 0   # it takes power: the reader's harm, as before
	if toughness_given and found.get_string(4) == "-":
		return 2 if power_given else 0
	return 1 if power_given or toughness_given else 0


static func _read_shape(text: String) -> Dictionary:
	# The phrase has to be what the effect acts on ("each attacking
	# creature", "target nonblack attacking creature", "Attacking creatures
	# get …"), not a rider further down the line.
	var attack := text.contains("if it's attacking") or text.contains("attacking or blocking") \
		or text.contains("by attacking creatures") or text.contains("by an attacking creature") \
		or _regex("attack", "(target|each|all|every)( [a-z-]+){0,3} attacking creature").search(text) != null \
		or _regex("attack0", "(^|\\. |\\n|• )attacking creatures").search(text) != null
	var block := text.contains("if it's blocking") or text.contains("were blocked by") or text.contains("wall blocked") \
		or text.contains("creatures blocking target") \
		or _regex("block", "(target|each|all|every)( [a-z-]+){0,2} (blocking|blocked|unblocked) creature").search(text) != null \
		or _regex("block0", "(^|\\. |\\n|• )blocking creatures").search(text) != null
	# "Prevent all combat damage that would be dealt this turn", "… by
	# target creature this turn": nothing to prevent outside a combat.
	var combat := text.contains("combat damage that would be dealt") \
		or text.contains("would deal combat damage")
	var hidden := text.contains("library") or text.contains("random") \
		or text.contains("reveal") or text.contains("look at") or text.contains("flip") \
		or text.contains("search") or text.contains("subgame") \
		or _regex("ante", "\\bante\\b").search(text) != null \
		or text.contains("card name") or text.contains("draw") or text.contains("discard") \
		or text.contains("copy") or text.contains("fast effect") \
		or text.replace("mana value", "").contains("mana") \
		or _regex("add", "\\badd\\b").search(text) != null \
		or _regex("hand", "(?<!to its owner's )(?<!to their owner's )(?<!to their owners' )(?<!to their )(?<!to your )(?<!to owner's )hand").search(text) != null
	var over_set := _regex("set", "\\b(all|each|every)\\b").search(text) != null
	# "… equal to the damage dealt to you this turn", "… dealt to you so far
	# this turn by artifacts": a count that is nothing until damage lands.
	var tally := 0
	if text.contains("the damage dealt to you this turn") \
			or text.contains("the damage dealt to you so far this turn"):
		tally = 2 if _regex("tally", "this turn by (an )?artifacts?\\b").search(text) != null else 1
	return {"attack": attack, "block": block, "combat": combat, "hidden": hidden,
		"set": over_set, "choice": text.contains("choose one") or text.contains("choose two"),
		"trick": _read_trick(text), "tally": tally, "guard": _read_guard(text), "sole": false}


## Is a creature attacking right now?
static func attackers_declared(g: MtgGame) -> bool:
	for id in g.combat.attackers:
		var body := g.find_instance(id)
		if body != null and body.zone == Mtg.Zone.BATTLEFIELD:
			return true
	return false


## Is a creature blocking right now?
static func blockers_declared(g: MtgGame) -> bool:
	if g.awaiting_blockers or not attackers_declared(g):
		return false
	for id in g.combat.attackers:
		if not g.combat.blockers_of(id).is_empty():
			return true
	return false


# -------------------------------------------------------------- the rules --

## Why [param inst], a card in the pilot's hand, is not cast at this moment
## ("" when nothing here objects) — asked by [method AiPlayer._cast_gate]
## of every card, so it reads the card's shape (once per card name) and the
## combat's state and nothing else.
static func cast_refusal(g: MtgGame, pilot, inst: CardInstance) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	var data: CardData = inst.data
	if data.is_permanent_type() or data.oracle_text.is_empty():
		return ""
	var shape := shape_of(data)
	if int(shape["tally"]) != 0 and tally_of(g, pilot.pid, int(shape["tally"])) <= 0:
		return "no damage was dealt to it this turn"
	# A guard or a switch nobody else reads is this module's to cast, at its
	# moment ([method respond]); a switch may be the main phase's when it
	# kills ([method sized_refusal] answers). The 1997 damage windows keep
	# their own rule.
	if int(shape["guard"]) != 0 and shape["sole"] and not pilot.has_meta(_OPEN) \
			and not g.awaiting_damage_prevention and not g.awaiting_regeneration \
			and not (int(shape["guard"]) == GUARD_SWITCH and g.active_player == pilot.pid
				and Mtg.is_main_step(g.current_step()) and g.stack.is_empty()):
		return "it is kept for its moment"
	# A trick nobody else reads is a held instant's: no combat, no cast. A
	# pilot that holds none casts it in its own main phase, like its pumps.
	if int(shape["trick"]) != 0 and pilot.profile.holds_instants \
			and inst.is_type(Mtg.CardType.INSTANT) \
			and not (g.awaiting_attackers or g.awaiting_blockers or attackers_declared(g)):
		return "no creature is attacking"
	if not (shape["attack"] or shape["block"] or shape["combat"]):
		return ""
	# A card with a real choice of modes may have one that needs no combat:
	# the forecast of the mode it picks answers for it.
	if shape["choice"]:
		return ""
	# The declaration itself counts as the combat: the planner prices a
	# trick in hand while it chooses its attackers and blockers.
	if g.awaiting_attackers or g.awaiting_blockers:
		return ""
	if shape["attack"] or shape["combat"]:
		return "" if attackers_declared(g) else "no creature is attacking"
	return "" if blockers_declared(g) else "no creature is blocking"


## The damage a spell of [code]tally[/code] shape [param kind] would count
## for [param pid] now: what the turn has dealt (by artifacts for kind 2),
## and what waits on that player in a 1997 damage prevention window.
static func tally_of(g: MtgGame, pid: int, kind: int) -> int:
	var me: MtgPlayer = g.players[pid]
	var total: int = me.artifact_damage_this_turn if kind == 2 else me.damage_taken_this_turn
	if g.rules.damage_prevention_window and g.awaiting_damage_prevention:
		for packet in g.damage_pending:
			if packet.target == null or not packet.target.is_player \
					or packet.target.player_id != pid:
				continue
			if kind == 2 and (packet.source == null
					or not packet.source.is_type(Mtg.CardType.ARTIFACT)):
				continue
			total += packet.remaining()
	return total


## Why the cast the main-phase ranking has just sized — [param sized] is
## [method AiPlayer._plan_spell_choice]'s row: mode, x, targets, value — is
## not made ("" when it may be): an X too small, a cast that changes
## nothing, a set not worth the card.
static func sized_refusal(g: MtgGame, pilot, inst: CardInstance, sized: Dictionary) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	var data: CardData = inst.data
	if data.is_permanent_type() or data.oracle_text.is_empty():
		return ""
	if float(sized.get("value", 0.0)) >= GAME:
		return ""   # it wins the game: never held
	var mode := int(sized.get("mode", 0))
	var x := int(sized.get("x", 0))
	var targets: Array = sized.get("targets", [])
	if int(shape_of(data)["guard"]) == GUARD_SWITCH and shape_of(data)["sole"]:
		return _switch_in_main(g, pilot, inst, sized)
	var intent: EffectIntent = pilot._mode_intent(data, mode)
	if data.cost.has_x and x < x_floor(g, pilot, inst, intent, mode, targets, x):
		return "its X is too small yet"
	if data.cost.has_x and life_not_needed(g, pilot, data, mode, targets, x):
		return "its life is not needed yet"
	if data.cost.has_x and not g.untap_caps.is_empty() and pilot.OWN_GOAL.x_refusal(g, pilot, inst, sized): return "the mana is kept for a better card"   # tolls: the stock under a land cap (own_goal.gd)
	if intent.adds_mana or intent.counters or intent.extra_turns > 0:
		return ""
	# A shield for this turn, with no spell on the stack and no attacker
	# declared: there is nothing to prevent.
	if g.stack.is_empty() and not attackers_declared(g) and is_shield(_mode_text(pilot, data, mode)):
		return "there is nothing to prevent"
	var shape := shape_of(data)
	if shape["hidden"]:
		return ""   # its outcome is not ours to know: no forecast
	# A shape another knob of the profile prices stays that knob's while it
	# is off (the blast, the mass pump): its null arm is the pilot as it was.
	var effects: Array = data.spell_effects
	if data.is_modal():
		effects = data.modes[clampi(mode, 0, data.modes.size() - 1)]["effects"]
	if (intent.blasts and not pilot.profile.prices_fallout) \
			or (not pilot.profile.uses_tactical_effects
				and EffectIntent.tactical_effect(effects) != null):
		return ""
	# The damage of this turn, counted: cast only when what it gives back
	# is more than what it takes (the creature of ours it lands on).
	if int(shape["tally"]) != 0:
		var back := forecast(g, pilot, inst, targets, x, mode)
		if not back.is_empty() and int(back["end"]) == 0 and float(back["swing"]) <= 0.0:
			return "it would take more than it gives"
		return ""
	# The damage window's own cards ("… equal to the damage dealt to you
	# this turn") keep the moment the pilot already gives them.
	for e in effects:
		if e.is_damage_prevention:
			return ""
	var seen := forecast(g, pilot, inst, targets, x, mode)
	if seen.is_empty() or int(seen["end"]) > 0:
		return ""
	if int(seen["end"]) < 0:
		return "it would lose the game"
	if not bool(seen["changed"]):
		return "it would change nothing"
	# A set of permanents, read by nobody else: what each side loses must
	# come to about a card.
	if shape["set"] and intent.sweeper == null \
			and (int(seen["theirs_lost"]) + int(seen["ours_lost"]) > 0
				or int(seen["life"][0]) < 0) \
			and float(seen["swing"]) < CARD_BAR:
		return "it is not worth the card"
	return ""


## A switch in our own main phase: worth its card only at a creature across
## the table that dies of it (power 0 or less becomes its toughness) — the
## forecast says which, and [param sized] is aimed there; "kept" otherwise.
static func _switch_in_main(g: MtgGame, pilot, inst: CardInstance, sized: Dictionary) -> String:
	var pid: int = pilot.pid
	var spec: TargetSpec = inst.data.spell_effects[0].target_spec
	var best: TargetRef = null
	var best_gain := CARD_BAR
	var tried := 0
	for body in g.players[g.opponent_of(pid)].battlefield:
		if not body.is_creature() or body.cur_power > 0 or tried >= AIM_CAP:
			continue
		var ref := TargetRef.card(body)
		if not g.target_legal_at(spec, ref, inst, 0, []):
			continue
		tried += 1
		var seen := forecast(g, pilot, inst, [ref], 0, 0)
		if seen.is_empty() or int(seen["end"]) < 0:
			continue
		var gain: float = GAME if int(seen["end"]) > 0 else float(seen["swing"])
		if gain >= best_gain:
			best = ref
			best_gain = gain
	if best == null:
		return "it is kept for a combat"
	sized["targets"] = [best]
	return ""


## The printed line of the mode a cast was sized with: the mode's own
## label for a card with a real choice of modes, the card's text otherwise.
static func _mode_text(pilot, data: CardData, mode: int) -> String:
	if data.is_modal() and not pilot._payment_rows_only(data) \
			and mode >= 0 and mode < data.modes.size():
		return String(data.modes[mode].get("label", ""))
	return data.oracle_text


## Does [param text] open with a shield that lasts the turn — "Prevent the
## next 3 damage …", "The next time a source of your choice would deal
## damage to you this turn, …", "Prevent all damage that would be dealt to
## target creature this turn.", "Regenerate target creature."?
static func is_shield(text: String) -> bool:
	for sentence in plain(text).replace("\n", ". ").split(". "):
		var line := sentence.strip_edges()
		if line.is_empty() or line.begins_with("buyback") or line.contains("rather than pay"):
			continue   # how it is paid for, not what it does
		if line.begins_with("until end of turn, if damage would be dealt") \
				or line.begins_with("regenerate target"):
			return true
		return line.contains("this turn") \
			and (line.begins_with("prevent ") or line.begins_with("the next time "))
	return false


## The X below which a spell that only scales with its X is held: 0 for a
## spell sized to a permanent it names, a sweep, a draw or a burn (each has
## a rule of its own in the pilot); [constant X_FLOOR] for life gained, 2
## for anything else. Lifted when the life is needed now or the hand is so
## full the card would be discarded.
static func x_floor(g: MtgGame, pilot, inst: CardInstance, intent: EffectIntent, mode: int,
		targets: Array, x: int) -> int:
	if intent.sweeper != null or intent.draws_use_x or intent.damage_uses_x \
			or intent.blasts or intent.is_tap_utility():
		return 0
	for t in targets:
		if t is TargetRef and not t.is_player:
			return 0   # sized to the thing it names
	var data: CardData = inst.data
	var me: MtgPlayer = g.players[pilot.pid]
	if me.hand.size() > HAND_FULL:
		return 0
	var effects: Array = data.spell_effects
	if data.is_modal():
		effects = data.modes[clampi(mode, 0, data.modes.size() - 1)]["effects"]
	if int(pilot._own_life_gain(effects, targets, x)) >= 0:
		return 0 if pilot._in_danger(g) else X_FLOOR
	return 2


## Is this an X of nothing but the pilot's own life, at a life total that
## has no use for it — the starting life or above, the board across no
## danger, and the hand not so full the card would be discarded?
static func life_not_needed(g: MtgGame, pilot, data: CardData, mode: int, targets: Array,
		x: int) -> bool:
	var me: MtgPlayer = g.players[pilot.pid]
	if me.life < int(pilot.FULL_LIFE) or me.hand.size() > HAND_FULL:
		return false
	var effects: Array = data.spell_effects
	if data.is_modal():
		effects = data.modes[clampi(mode, 0, data.modes.size() - 1)]["effects"]
	return int(pilot._own_life_gain(effects, targets, x)) >= 0 and not pilot._in_danger(g)


## A combat spell cast in the combat it was held for, or "" — an arm of
## [method AiPlayer._respond_action]. Only an untargeted instant whose
## printed effect is over the attackers, the blockers or the combat damage,
## and that no other responder of the pilot's owns (a Fog, a counter, a
## pump): forecast at once, and through the declared combat when the blocks
## are known, and cast when the board it leaves is better by
## [constant CARD_BAR] or the game is saved.
##
## Two more arms for a pilot that holds instants: the trick nobody else
## reads ([method trick_of]), on the creature in the declared combat where
## it pays; and the damage of this turn, counted at an end step.
##
## A pilot that holds no instant ([method AiPlayer.act] asks for it) has
## the combat arms only, and for every spell whose printed effect needs
## the combat — it has no other responder to leave a pump or an aimed one to.
static func respond(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics or g.awaiting_attackers or g.awaiting_blockers:
		return ""
	if not g.stack.is_empty():
		return _respond_stack(g, pilot) if pilot.profile.holds_instants else ""
	var step := g.current_step()
	if step == Mtg.Step.END:
		return _respond_tally(g, pilot) if pilot.profile.holds_instants else ""
	if step != Mtg.Step.DECLARE_ATTACKERS and step != Mtg.Step.DECLARE_BLOCKERS:
		return ""
	var cast := _respond_unaimed(g, pilot, step)
	if cast == "" and step == Mtg.Step.DECLARE_BLOCKERS:
		cast = _respond_aimed(g, pilot)
	return cast


static func _respond_unaimed(g: MtgGame, pilot, step: int) -> String:
	var pid: int = pilot.pid
	var hand: Array = g.players[pid].hand
	var solo: bool = not pilot.profile.holds_instants
	var candidates: Array[CardInstance] = []
	for inst in hand:
		var data: CardData = inst.data
		if data.is_permanent_type() or not inst.is_type(Mtg.CardType.INSTANT) \
				or data.is_modal() or data.cost.has_x:
			continue
		var shape := shape_of(data)
		if not (shape["attack"] or shape["block"] or shape["combat"]) or shape["hidden"]:
			continue
		var aimed := false
		for e in data.spell_effects:
			if e.target_spec != null:
				aimed = true
		if aimed or pilot._is_reactive(data):
			continue
		var intent: EffectIntent = EffectIntent.read(data.spell_effects, data.card_name)
		if intent.fogs or intent.counters:
			continue   # the reactive game's card
		if not solo and (intent.pumps
				or (pilot.profile.uses_tactical_effects
					and EffectIntent.tactical_effect(data.spell_effects) != null)):
			continue   # another responder's card
		if pilot._refused.has(str(inst.id)) or pilot._cast_gate(g, inst) != "":
			continue
		candidates.append(inst)
	if candidates.is_empty():
		return ""
	if not attackers_declared(g):
		return ""
	var sources: Array = pilot._mana_sources(g)
	var through := step == Mtg.Step.DECLARE_BLOCKERS
	var base := combat_baseline(g, pilot) if through else {"swing": 0.0, "end": 0}
	var best: CardInstance = null
	var best_gain := CARD_BAR
	for inst in candidates:
		var extra: int = g.spell_surcharge(pid, inst.data)
		if pilot._plan_taps_from(sources, inst.data.cost, extra,
				g.mana_usage_keys(inst.data, inst)).is_empty() \
				and not pilot._free_at(inst.data.cost, extra):
			continue
		var seen := forecast(g, pilot, inst, [], 0, 0, through)
		if seen.is_empty() or int(seen["end"]) < 0:
			continue
		var gain: float = float(seen["swing"]) - float(base["swing"])
		if int(seen["end"]) > int(base["end"]):
			gain = GAME   # the combat was lost, or is now won
		if gain >= best_gain:
			best = inst
			best_gain = gain
	if best == null:
		return ""
	return pilot._cast_response(g, best, [])


## The aimed spell in the declared combat, blocks known: the trick nobody
## else reads (a pilot that holds instants), or any one-target instant
## whose printed effect needs the combat (a pilot that holds none). Tried
## on each creature in the combat it may name — a gift on ours only — and
## cast on the one where the fight ends better by [constant CARD_BAR].
static func _respond_aimed(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	var solo: bool = not pilot.profile.holds_instants
	var candidates: Array[CardInstance] = []
	for inst in g.players[pid].hand:
		var data: CardData = inst.data
		if data.is_permanent_type() or not inst.is_type(Mtg.CardType.INSTANT) \
				or data.is_modal() or data.cost.has_x or data.spell_effects.size() != 1:
			continue
		var shape := shape_of(data)
		if shape["hidden"]:
			continue
		if int(shape["guard"]) != 0:
			pass   # a guard or a switch: the declared combat is its moment
		elif int(shape["trick"]) == 0 or solo:
			# The pilot that holds no instant: a spell of the combat's, aimed
			# at one creature, and not the reactive game's.
			if not solo or not (shape["attack"] or shape["block"]):
				continue
			var e: EffectBase = data.spell_effects[0]
			if e.target_spec == null or e.target_spec.kind != TargetSpec.Kind.CREATURE \
					or e.target_count_is_x or e.is_damage_prevention or pilot._is_reactive(data):
				continue
		if pilot._refused.has(str(inst.id)) or not _gate_open(g, pilot, inst):
			continue
		candidates.append(inst)
	if candidates.is_empty() or not attackers_declared(g):
		return ""
	var bodies: Array[CardInstance] = []
	for id in g.combat.attackers:
		var attacker := g.find_instance(id)
		if attacker != null and attacker.zone == Mtg.Zone.BATTLEFIELD:
			bodies.append(attacker)
		for blocker_id in g.combat.blockers_of(id):
			var blocker := g.find_instance(blocker_id)
			if blocker != null and blocker.zone == Mtg.Zone.BATTLEFIELD \
					and not bodies.has(blocker):
				bodies.append(blocker)
	var sources: Array = pilot._mana_sources(g)
	var base := combat_baseline(g, pilot)
	var best: CardInstance = null
	var best_ref: TargetRef = null
	var best_gain := CARD_BAR
	var tried := 0
	for inst in candidates:
		var extra: int = g.spell_surcharge(pid, inst.data)
		if pilot._plan_taps_from(sources, inst.data.cost, extra,
				g.mana_usage_keys(inst.data, inst)).is_empty() \
				and not pilot._free_at(inst.data.cost, extra):
			continue
		var spec: TargetSpec = inst.data.spell_effects[0].target_spec
		var guard := int(shape_of(inst.data)["guard"])
		var gift: bool = int(shape_of(inst.data)["trick"]) == 1 \
			or guard == GUARD_SHIELD or guard == GUARD_INSURANCE
		for body in bodies:
			if gift and body.controller_id != pid:
				continue
			var ref := TargetRef.card(body)
			if tried >= AIM_CAP or not g.target_legal_at(spec, ref, inst, 0, []) \
					or pilot._aims_at_own_fragile(g, [ref]):
				continue
			tried += 1
			var seen := forecast(g, pilot, inst, [ref], 0, 0, true)
			if seen.is_empty() or int(seen["end"]) < 0:
				continue
			var gain: float = float(seen["swing"]) - float(base["swing"])
			if int(seen["end"]) > int(base["end"]):
				gain = GAME
			# A switch is for the fight it turns: a creature of theirs
			# more, or one of ours fewer, dies of it — never a point of life.
			elif guard == GUARD_SWITCH \
					and int(seen["theirs_lost"]) <= int(base["theirs_lost"]) \
					and int(seen["ours_lost"]) >= int(base["ours_lost"]):
				continue
			if gain >= best_gain:
				best = inst
				best_ref = ref
				best_gain = gain
	if best == null:
		return ""
	return pilot._cast_response(g, best, [best_ref])


## The pilot's own gate, asked for a card this module casts itself.
static func _gate_open(g: MtgGame, pilot, inst: CardInstance) -> bool:
	pilot.set_meta(_OPEN, true)
	var why: String = pilot._cast_gate(g, inst)
	pilot.remove_meta(_OPEN)
	return why == ""


## The guard in answer: a spell or ability of theirs on top of the stack
## names a creature of ours, and a shield, an insurance or a switch in hand
## is forecast on that creature — the stack resolved with it against the
## stack resolved without — and cast when we end about a card better.
static func _respond_stack(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	var candidates: Array[CardInstance] = []
	for inst in g.players[pid].hand:
		if inst.is_type(Mtg.CardType.INSTANT) and guard_of(inst.data) != 0:
			candidates.append(inst)
	if candidates.is_empty():
		return ""
	var top: StackItem = g.stack.back()
	if top.controller == pid:
		return ""
	# What their spell does must be the table's to know: no forecast of a
	# draw, a reveal, a coin.
	if top.card != null and not top.card.data.oracle_text.is_empty() \
			and shape_of(top.card.data)["hidden"]:
		return ""
	var victims: Array[CardInstance] = []
	for t in top.targets:
		if t == null or t.is_player or t.is_damage or t.is_ability:
			continue
		var victim := g.find_instance(t.instance_id)
		if victim != null and victim.controller_id == pid and victim.is_creature() \
				and victim.zone == Mtg.Zone.BATTLEFIELD and not victims.has(victim) \
				and victims.size() < AIM_CAP:
			victims.append(victim)
	if victims.is_empty():
		return ""
	var sources: Array = pilot._mana_sources(g)
	var base := {}
	var best: CardInstance = null
	var best_ref: TargetRef = null
	var best_gain := CARD_BAR
	for inst in candidates:
		if pilot._refused.has(str(inst.id)) or not _gate_open(g, pilot, inst):
			continue
		var extra: int = g.spell_surcharge(pid, inst.data)
		if pilot._plan_taps_from(sources, inst.data.cost, extra,
				g.mana_usage_keys(inst.data, inst)).is_empty() \
				and not pilot._free_at(inst.data.cost, extra):
			continue
		if base.is_empty():
			base = forecast_stack(g, pilot, null, [])
			if base.is_empty() or int(base["end"]) != 0:
				return ""
		var spec: TargetSpec = inst.data.spell_effects[0].target_spec
		for victim in victims:
			var ref := TargetRef.card(victim)
			if not g.target_legal_at(spec, ref, inst, 0, []) \
					or pilot._aims_at_own_fragile(g, [ref]):
				continue
			var seen := forecast_stack(g, pilot, inst, [ref])
			if seen.is_empty() or int(seen["end"]) < 0:
				continue
			var gain: float = float(seen["swing"]) - float(base["swing"])
			if gain >= best_gain:
				best = inst
				best_ref = ref
				best_gain = gain
	if best == null:
		return ""
	return pilot._cast_response(g, best, [best_ref])


## The damage of this turn, counted at an end step — the last moment
## before the cleanup forgets it: a spell of that shape is forecast, on
## each creature of ours it may name when it names one, and cast when what
## it gives back is worth the card, or anything at all while the pilot is
## in danger or would discard it.
static func _respond_tally(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	var me: MtgPlayer = g.players[pid]
	var best: CardInstance = null
	var best_targets: Array = []
	var best_gain := 0.0
	var sources: Array = []
	for inst in me.hand:
		var data: CardData = inst.data
		if data.is_permanent_type() or not inst.is_type(Mtg.CardType.INSTANT) \
				or data.oracle_text.is_empty() or data.is_modal() or data.cost.has_x \
				or data.spell_effects.size() != 1 or int(shape_of(data)["tally"]) == 0:
			continue
		if pilot._refused.has(str(inst.id)) or pilot._cast_gate(g, inst) != "":
			continue   # no damage this turn, among the rest
		if sources.is_empty():
			sources = pilot._mana_sources(g)
		var extra: int = g.spell_surcharge(pid, data)
		if pilot._plan_taps_from(sources, data.cost, extra,
				g.mana_usage_keys(data, inst)).is_empty() \
				and not pilot._free_at(data.cost, extra):
			continue
		var rows: Array = [[]]
		var spec: TargetSpec = data.spell_effects[0].target_spec
		if spec != null:
			rows = []
			for ref in g.legal_targets_at(spec, inst, 0):
				if rows.size() < AIM_CAP and not pilot._aims_at_own_fragile(g, [ref]):
					rows.append([ref])
		for row in rows:
			var seen := forecast(g, pilot, inst, row, 0, 0)
			if seen.is_empty() or int(seen["end"]) < 0:
				continue
			var gain: float = GAME if int(seen["end"]) > 0 else float(seen["swing"])
			if gain > best_gain:
				best = inst
				best_targets = row
				best_gain = gain
	if best == null:
		return ""
	if best_gain < CARD_BAR and not pilot._in_danger(g) \
			and not (g.active_player == pid and me.hand.size() > HAND_FULL):
		return ""
	return pilot._cast_response(g, best, best_targets)



# ------------------------------------------------------------ the forecast --

## What casting [param inst] with [param targets], [param x] and
## [param mode] would do right now — the cast itself, paid from mana lent
## for the forecast, resolved under the search journal with the heuristic
## agents answering, and everything put back. [code]{}[/code] when the
## engine refuses the cast or it does not finish. Otherwise:
## [code]changed[/code] — did anything but the card and the mana move;
## [code]swing[/code] — what the table gained for the pilot, in the
## Evaluator's units: permanents each side lost (a bounced one at half) or
## gained, life at the pilot's own price, cards drawn and discarded;
## [code]end[/code] — +1 the cast wins the game, -1 it loses it;
## with [param through_combat], the declared combat is dealt after it and
## counted too.
static func forecast(g: MtgGame, pilot, inst: CardInstance, targets: Array, x: int,
		mode: int, through_combat := false, debug: Array = []) -> Dictionary:
	var pid: int = pilot.pid
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g._rec_turn()
	g._rec(g, &"agents")
	g.agents = [DecisionAgent.new(), DecisionAgent.new()]   # nobody is asked
	var journal: UndoLog = g.undo_log
	var from := journal.size()
	var before := _census(g, pilot)
	if inst.zone == Mtg.Zone.HAND:
		before["hand"][inst.owner_id] -= 1   # the card itself is the price, not a loss
	for color in _COLORS:
		g.players[pid].mana_pool.add(color, 60)
	var depth := g.stack.size()
	var result := {}
	if g.cast_spell(pid, inst, targets, x, mode) == "":
		var guard := 0
		var stuck := false
		while g.stack.size() > depth and not g.game_over and guard < 60:
			if g.pass_priority(g.priority_player) != "":
				stuck = true
				break
			guard += 1
		if not stuck and (g.game_over or g.stack.size() <= depth):
			var changed := _journal_changed(g, journal, from, inst, debug)
			# The card itself, set aside with something on it (two scream
			# counters), is an effect still to come.
			if inst.zone != Mtg.Zone.GRAVEYARD and inst.zone != Mtg.Zone.HAND \
					and not inst.counters.is_empty():
				changed = true
			var combat := {}
			if through_combat and not g.game_over:
				combat = g.forecast_damage(true)
			result = _measure(g, pilot, before, combat)
			result["changed"] = changed or float(result["swing"]) != 0.0
	g.unmake_to(mark)
	if not nested:
		g.end_search()
	return result


## What the stack as it stands leaves once it has resolved — after casting
## [param inst] with [param targets] on top of it, or with no cast at all
## ([param inst] null): [method forecast]'s count, [code]{}[/code] when the
## cast is refused or the stack does not empty (a question nobody answers,
## a 1997 damage window).
static func forecast_stack(g: MtgGame, pilot, inst: CardInstance, targets: Array) -> Dictionary:
	var pid: int = pilot.pid
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g._rec_turn()
	g._rec(g, &"agents")
	g.agents = [DecisionAgent.new(), DecisionAgent.new()]   # nobody is asked
	var before := _census(g, pilot)
	var result := {}
	var cast := true
	if inst != null:
		before["hand"][inst.owner_id] -= 1
		for color in _COLORS:
			g.players[pid].mana_pool.add(color, 60)
		cast = g.cast_spell(pid, inst, targets, 0, 0) == ""
	if cast:
		var guard := 0
		var stuck := false
		while not g.stack.is_empty() and not g.game_over and guard < 60:
			if g.pass_priority(g.priority_player) != "":
				stuck = true
				break
			guard += 1
		if not stuck and (g.game_over or g.stack.is_empty()):
			result = _measure(g, pilot, before, {})
	g.unmake_to(mark)
	if not nested:
		g.end_search()
	return result


## The declared combat as it stands, with no cast: the same count the
## forecast makes, for the difference a combat spell makes.
static func combat_baseline(g: MtgGame, pilot) -> Dictionary:
	return _measure(g, pilot, _census(g, pilot), g.forecast_damage(true))


## The public table before a forecast: each permanent's worth and side, the
## life totals, the hand sizes.
static func _census(g: MtgGame, pilot) -> Dictionary:
	var worth := {}
	var side := {}
	for body in g.all_battlefield():
		worth[body.id] = _worth(body, pilot)
		side[body.id] = body.controller_id
	return {"worth": worth, "side": side,
		"life": [g.players[0].life, g.players[1].life],
		"hand": [g.players[0].hand.size(), g.players[1].hand.size()]}


static func _worth(body: CardInstance, pilot) -> float:
	if body.is_land():
		return 1.0
	return Evaluator.permanent_value(body, pilot.profile)


## The table after a forecast against [param before]. [param combat] is
## [method MtgGame.forecast_damage]'s answer when the declared combat is
## counted too.
static func _measure(g: MtgGame, pilot, before: Dictionary, combat: Dictionary) -> Dictionary:
	var pid: int = pilot.pid
	var foe: int = g.opponent_of(pid)
	var worth: Dictionary = before["worth"]
	var side: Dictionary = before["side"]
	var swing := 0.0
	var theirs_lost := 0
	var ours_lost := 0
	var here := {}
	var bounced := [0, 0]
	for body in g.all_battlefield():
		if not combat.is_empty() and not combat["alive"].has(body.id):
			continue   # the combat takes it
		here[body.id] = true
		if not worth.has(body.id):
			var made := _worth(body, pilot)
			swing += made if body.controller_id == pid else -made
		elif int(side[body.id]) != body.controller_id:
			# It changed sides: lost by one, gained by the other.
			swing += 2.0 * float(worth[body.id]) * (1.0 if body.controller_id == pid else -1.0)
	# A creature the combat brought back from a graveyard ("When that
	# creature dies this turn, return a creature card …"): made, for its
	# owner, at the size the combat's forecast saw.
	if not combat.is_empty():
		for id in combat["alive"]:
			if here.has(id):
				continue
			var back := g.find_instance(id)
			if back == null or back.zone != Mtg.Zone.GRAVEYARD:
				continue
			here[id] = true
			if worth.has(id):
				continue
			var size: Vector2i = combat["stats"].get(id, Vector2i.ZERO)
			var made := maxf(float(size.x + size.y), 0.5)
			swing += made if back.owner_id == pid else -made
	for id in worth:
		if here.has(id):
			continue
		var lost := float(worth[id])
		var body := g.find_instance(id)
		if body != null and body.zone == Mtg.Zone.HAND:
			lost *= 0.5   # a bounce is a turn, not the card
			bounced[body.owner_id] += 1
		if int(side[id]) == pid:
			swing -= lost
			ours_lost += 1
		else:
			swing += lost
			theirs_lost += 1
	var life: Array = [g.players[0].life, g.players[1].life] if combat.is_empty() \
		else combat["life"]
	var end := 0
	if int(life[pid]) <= 0 or (g.game_over and g.winner != pid):
		end = -1
	elif int(life[foe]) <= 0 or (g.game_over and g.winner == pid):
		end = 1
	var mine: int = int(life[pid]) - int(before["life"][pid])
	var their: int = int(life[foe]) - int(before["life"][foe])
	swing += float(mine) * float(pilot._life_price(mini(int(life[pid]), int(before["life"][pid]))))
	swing -= float(their) * Evaluator.W_LIFE * 0.5
	# Cards: the spell itself and what a bounce handed back are not a draw.
	var my_cards: int = g.players[pid].hand.size() - int(before["hand"][pid]) - int(bounced[pid])
	var their_cards: int = g.players[foe].hand.size() - int(before["hand"][foe]) - int(bounced[foe])
	swing += float(my_cards - their_cards) * float(pilot.profile.w_hand)
	return {"swing": swing, "end": end, "theirs_lost": theirs_lost, "ours_lost": ours_lost,
		"life": [mine, their]}


## Did the journal since [param from] record a change that is not the
## cast's own bookkeeping — the card leaving the hand for the graveyard,
## the mana, the priority passes?
static func _journal_changed(g: MtgGame, journal: UndoLog, from: int, inst: CardInstance,
		debug: Array) -> bool:
	var seen := {}
	var changed := false
	for i in range(from, journal.size()):
		var obj: Object = journal._obj[i]
		var prop: StringName = journal._prop[i]
		if obj == null or obj == inst or obj is ManaPool:
			continue
		var key := [obj.get_instance_id(), prop]
		if seen.has(key):
			continue
		seen[key] = true
		if (obj == g and prop in _GAME_NOISE) or prop in _OTHER_NOISE:
			continue
		if obj is StackItem:
			continue   # the spell's own item, made and resolved
		var was: Variant = journal._val[i]
		var now: Variant = obj.get(prop)
		if was is Array and now is Array:
			if _without(was, inst) == _without(now, inst):
				continue
		elif typeof(was) == typeof(now) and was == now:
			continue
		elif was == null and now == null:
			continue
		changed = true
		debug.append("%s.%s" % [obj.get_class() if obj.get_script() == null \
			else String(obj.get_script().resource_path).get_file(), prop])
	return changed


static func _without(list: Array, inst: CardInstance) -> Array:
	var out: Array = []
	for item in list:
		if not (item is Object and item == inst):
			out.append(item)
	return out
