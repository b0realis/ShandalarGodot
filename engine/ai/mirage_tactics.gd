extends RefCounted
## THE MIRAGE BLOCK'S SHAPES (Pack 8, 2026-10-03) — the fair AI's readings
## of the effects Mirage, Visions and Weatherlight brought: phasing,
## flanking's leftovers, flash, the targeting role, the damage-replacement
## suite, entry-cost lands, the instant-only mana and the turn skips.
##
## THE INFORMATION RULE (CONTRIBUTING.md rule 8, docs/fair-play.md): every
## reading here is the public board, the stack, its own hand and its own
## registered deck. A phased-out permanent is PUBLIC (CR 702.26 — it sits
## in a list both seats can see), a face-down permanent it does not
## control is the 2/2 it shows ([method MtgGame.predict_damage]'s
## `viewer`), and no library order, hidden hand or RNG state is read.
##
## THE GATES are the profile's existing capabilities, never a new scale
## (docs/ai-difficulty.md §1): [member AiProfile.forecasts_tactics] — on at
## every rung, the Pack 5 precedent — for the correctness readings (a card
## that would be lost, a refused cast, a sweeper it could not see), and
## [member AiProfile.reads_gaze] for the combat readings, which is the knob
## that already carries rampage and flanking. Responses run only where
## [method AiPlayer._respond_action] runs ([member AiProfile.holds_instants]).
## Every arm answers null or "" with its gate off, so the null arm is the
## pilot as it was.
##
## Nothing here names a card. Shapes are read off typed effects, the
## card's own `ai_role` (cards/sets/{mir,vis,wth}/_phasing.gd: `phase_out`,
## `phase_out_self`, `phase_out_host`, `phase_swap`) or its printed line,
## the precedent [method EffectIntent.is_gaze] set.

const COSTS := preload("res://engine/additional_object_costs.gd")


# ================================================== lands with an entry --

## The printed shape of a bounce land's arrival trigger ("Sacrifice this
## land unless you return an untapped Plains you control to its owner's
## hand" — the Karoos), read off the line the way [method
## EffectIntent.rent_of_line] reads a rent.
const BOUNCE_PREFIX := "unless you return an untapped "

## The unit index the would-be land's floating rows start at, clear of the
## pool's own (which count up from 0 per colour).
const LAND_UNIT_BASE := 1000


## What keeping [param land] costs once it is played: `{"ok": bool,
## "eats": int, "eaten": Array[int], "returns": int}` — `ok` false when the
## land would be LOST (its entry payment cannot be made, or its bounce has
## no untapped land of the type to return), `eats` the permanents the
## entry payment takes off our table (their ids in `eaten`), `returns` the
## lands its arrival trigger sends back to hand.
##
## THE TWO SHAPES. An ENTRY PAYMENT ([member CardData.entry_payment] —
## Lotus Vale, Scorched Ruins, Pack 5's Soldevi Excavations and Lake of the
## Dead) is a callable this reader cannot see into, so it is RUN, under
## the search journal and with a heuristic agent answering its questions
## (the mechanism [method MtgGame.predict_damage] uses): whether it paid
## and what left our battlefield is the answer, and everything is put
## back. A BOUNCE TRIGGER is read off its printed line ([constant
## BOUNCE_PREFIX]): the type it names must be untapped on our side.
static func land_entry(g: MtgGame, pilot, land: CardInstance) -> Dictionary:
	var out := {"ok": true, "eats": 0, "eaten": [], "returns": 0}
	var pid: int = pilot.pid
	if land.data.entry_payment.is_valid():
		var probe := _probe_entry(g, pid, land)
		if not bool(probe["paid"]):
			out["ok"] = false
			return out
		out["eaten"] = probe["eaten"]
		out["eats"] = (probe["eaten"] as Array).size()
	for trig in land.data.triggered_abilities:
		if trig.event_type != Mtg.EventType.ENTERS_BATTLEFIELD:
			continue
		var kind := bounce_kind(trig.text)
		if kind == "":
			continue
		var found := false
		for i in g.players[pid].battlefield:
			if i != land and i.has_subtype(kind) and not i.tapped:
				found = true
				break
		if not found:
			out["ok"] = false
			return out
		out["returns"] = int(out["returns"]) + 1
	return out


## The land type a bounce trigger's line names ("plains"), or "".
static func bounce_kind(text: String) -> String:
	var lower := text.to_lower()
	var at := lower.find(BOUNCE_PREFIX)
	if at < 0:
		return ""
	var rest := lower.substr(at + BOUNCE_PREFIX.length())
	var space := rest.find(" ")
	return rest if space < 0 else rest.substr(0, space)


## Run [param land]'s entry payment under the search journal and put
## everything back: `{"paid": bool, "eaten": Array[int]}`.
static func _probe_entry(g: MtgGame, pid: int, land: CardInstance) -> Dictionary:
	var before: Array = g.players[pid].battlefield.duplicate()
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g._rec_turn()
	g._rec(g, &"agents")
	g.agents = [DecisionAgent.new(), DecisionAgent.new()]   # nobody is asked
	var paid := bool(land.data.entry_payment.call(g, land, pid))
	var eaten: Array = []
	for i in before:
		if not g.players[pid].battlefield.has(i):
			eaten.append(i.id)
	g.unmake_to(mark)
	if not nested:
		g.end_search()
	return {"paid": paid, "eaten": eaten}


## Does playing [param land] — after its entry has eaten [param eaten] —
## turn a card in hand from uncastable into castable this turn? The
## question [method AiPlayer._land_unlocks_a_cast] asks of a plain land,
## asked of the table the payment leaves: a spell the eaten lands could
## already pay for is not unlocked by trading them away.
static func entry_unlocks(g: MtgGame, pilot, land: CardInstance, eaten: Array) -> bool:
	var sources: Array = pilot._mana_sources(g)
	var left: Array = sources.filter(func(row: Array) -> bool:
		return row[0] == null or not eaten.has((row[0] as CardInstance).id))
	var colours: Dictionary = {}
	if not land.data.enters_tapped:
		for ability in land.data.mana_abilities:
			if ability.cost != null or ability.life_cost > 0 \
					or ability.counter_cost_kind != "" or ability.sacrifice_filter.is_valid():
				continue
			for pair in ability.produces:
				colours[int(pair[0])] = maxi(int(colours.get(int(pair[0]), 0)), int(pair[1]))
	if colours.is_empty():
		return false
	for inst in g.players[pilot.pid].hand:
		if inst == land or inst.is_land() or pilot._cast_gate(g, inst) != "":
			continue
		var surcharge := g.spell_surcharge(pilot.pid, inst.data)
		var keys: Array = g.mana_usage_keys(inst.data, inst)
		if pilot._cost_is_free(inst.data.cost) and surcharge == 0:
			continue
		if not pilot._plan_taps_from(sources, inst.data.cost, surcharge, keys).is_empty():
			continue   # castable already: the trade buys it nothing
		for colour in colours:
			var with_land: Array = left.duplicate()
			# One row per unit, each its own key ([method
			# ManaPlanner.source_key] reads the unit index): a land that
			# makes three is three units, never one counted thrice.
			for unit in int(colours[colour]):
				with_land.append([null, LAND_UNIT_BASE + unit, int(colour), 1, false, "", 0, 0])
			if not pilot._plan_taps_from(with_land, inst.data.cost, surcharge, keys).is_empty():
				return true
	return false


# ========================================================== the sweepers --

## THE SWEEP'S SCOPE (2026-10-03): the seat whose creatures [param effect]
## (a [DamageAllEffect] or [DestroyAllEffect]) reaches when [param caster]
## casts it, or -1 for every seat. Simoon — "1 damage to each creature
## target opponent controls" — carries a PLAYER spec and no creature
## filter, so the old reading had it hitting both sides of the table; the
## spec is the authority: an opponent-only spec reaches the caster's
## opponent, and a "target player" one is aimed at the opponent by
## whoever casts it to sweep ([method AiPlayer._pick_for_spec]'s seat).
static func sweep_scope(g: MtgGame, effect: EffectBase, caster: int) -> int:
	if effect == null or effect.target_spec == null \
			or effect.target_spec.kind != TargetSpec.Kind.PLAYER:
		return -1
	if not (effect is DamageAllEffect or effect is DestroyAllEffect):
		return -1
	return g.opponent_of(caster)


## Can the table change what [param amount] damage does to [param victim]
## — so a sweep's kill is worth asking [method MtgGame.predict_damage]
## about rather than reading toughness? A damage-replacement entry on the
## table (the E5 registry or a static one), protection, a prevention pool
## or shield of its own, a regeneration shield, or Ogre Enforcer's
## single-source rule. Most boards have none of these, and the prediction
## (a live run under the journal) is then skipped.
static func damage_is_shaped(g: MtgGame, victim: CardInstance) -> bool:
	if not g.damage_effects.is_empty() or not g.static_damage_effects.is_empty():
		return true
	if victim == null:
		return false
	return victim.cur_protection != 0 or victim.prevention > 0 \
		or victim.regeneration_shields > 0 or victim.cur_lethal_needs_single_source \
		or victim.cur_prevent_all_damage_taken or victim.cur_indestructible


# ================================================= dies when targeted --

static var _fragile_cache: Dictionary = {}

## Does [param inst] die the moment anything names it — "When this
## creature becomes the target of a spell or ability, sacrifice it"
## (Skulking Ghost, Tar Pit Warrior; engine package E4's BECAME_TARGET)?
## Read off the LIVE trigger list and its printed line, the reading
## [method EffectIntent.is_gaze] makes of a gaze: a silenced creature has
## no triggers and is not fragile. Public — the trigger is on the board.
static func dies_when_targeted(inst: CardInstance) -> bool:
	if inst == null:
		return false
	for trig in inst.cur_triggered_abilities:
		if trig.event_type != Mtg.EventType.BECAME_TARGET:
			continue
		var hit: Variant = _fragile_cache.get(trig.text)
		if hit == null:
			var lower := trig.text.to_lower()
			hit = lower.contains("becomes the target") and lower.contains("sacrifice it")
			_fragile_cache[trig.text] = hit
		if bool(hit):
			return true
	return false


## The opposing creature [param a]'s ability at [param index] can kill by
## NAMING it (2026-10-03): `{value, targets}` for the best such creature
## of theirs a legal target of the ability's first effect, or null when
## there is none. Any targeted ability is removal against one — a ping, a
## tap, a pump, a Healer's prevention. Priced as the victim (
## [method AiPlayer._victim_value]) plus a point for the card it is.
static func fragile_target_option(g: MtgGame, pilot, s: CardInstance, index: int) -> Variant:
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	if a.effects.is_empty() or a.effects[0].target_spec == null:
		return null
	var spec: TargetSpec = a.effects[0].target_spec
	if spec.kind == TargetSpec.Kind.PLAYER or spec.kind == TargetSpec.Kind.SPELL \
			or spec.kind == TargetSpec.Kind.ABILITY or spec.kind == TargetSpec.Kind.DAMAGE:
		return null
	var foe: int = g.opponent_of(pilot.pid)
	var best: Variant = null
	for i in g.players[foe].battlefield:
		if not i.is_creature() or not dies_when_targeted(i):
			continue
		var ref := TargetRef.card(i)
		if not spec.is_legal(g, ref, s):
			continue
		var value: float = pilot._victim_value(g, i) + 1.0
		if best == null or value > float(best["value"]):
			best = {"value": value, "targets": [ref]}
	return best


# ============================================== the activated abilities --

## The activated-ability arm, asked by [method AiPlayer._ability_option]
## after the other expansions' (`window` is [enum AiPlayer.Moment]'s name):
## null when no Mirage shape is involved, `{}` for "no, not now", or
## `{value, targets}`.
static func option(g: MtgGame, pilot, s: CardInstance, index: int, window: String) -> Variant:
	if not pilot.profile.forecasts_tactics:
		return null
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	if a.effects.is_empty():
		return null
	if window != "PRE_ATTACK":
		var fragile: Variant = fragile_target_option(g, pilot, s, index)
		if fragile != null:
			return fragile
	# Two flankers' own combat buttons, read off the printed line (card
	# batch B2 left them card-local): Searing Spear Askari's menace and
	# Knight of Valor's -1/-1 to its blockers.
	var torrent: Variant = torrent_option(g, pilot, s, a)
	if torrent != null:
		return torrent
	var skip: Variant = turn_skip_option(g, pilot, s, a, window)
	if skip != null:
		return skip
	var line := a.text.to_lower()
	if line.contains("this creature gains menace"):
		return menace_option(g, pilot, s, window)
	if line.contains("blocking this creature gets -1/-1"):
		return valor_option(g, pilot, s, window)
	var counted := counter_damage(s, a.effects[0])
	if counted >= 0:
		return counter_blast_option(g, pilot, s, a, counted, window)
	var fuel := fuelled_kind(s, a)
	if fuel != "":
		# A counter the same permanent turns into damage later (Magma
		# Mine's "{4}: Put a pressure counter"): bought with mana the
		# untap step would waste, and only by a pilot that plays engines.
		if window != "SINK" or not pilot.profile.plays_engines:
			return {}
		return {"value": 2.5, "targets": [], "bar": 0.5}
	if a.effects.size() == 2 and a.effects[0].target_spec != null \
			and a.effects[1].target_spec != null \
			and a.effects[0].target_spec.kind == TargetSpec.Kind.CREATURE \
			and a.effects[1].target_spec.kind == TargetSpec.Kind.CREATURE \
			and a.effects[1].describe().to_lower().contains("fights target creature"):
		return fight_pair_option(g, pilot, s, a, window)
	return null


# --------------------------------------------- counters turned into damage --

## "It deals damage equal to the number of <kind> counters on it" — a
## [DamageEffect] of 0 whose amount is read from the source's counters at
## resolution (Magma Mine, card batch B6). Read off its own line; -1 when
## [param e] is not that shape, else the live count on [param s].
static func counter_damage(s: CardInstance, e: EffectBase) -> int:
	var kind := _counted_kind(e)
	return -1 if kind == "" else int(s.counters.get(kind, 0))


static func _counted_kind(e: EffectBase) -> String:
	if not (e is DamageEffect) or e.amount != 0 or e.use_x:
		return ""
	var line := e.describe().to_lower()
	var at := line.find("damage equal to the number of ")
	if at < 0 or not line.contains(" counters on it"):
		return ""
	return line.substr(at + 30).split(" ", false)[0]


## The counter kind a "put a <kind> counter on this" ability of [param s]
## feeds into another of its abilities that turns it into damage, or "".
static func fuelled_kind(s: CardInstance, a: ActivatedAbility) -> String:
	if a.effects.size() != 1 or a.effects[0].target_spec != null \
			or a.effects[0] is PumpEffect:
		return ""
	# The other half first: only a permanent that turns a counter into
	# damage has a counter worth buying, and only its line is read.
	var kinds: Array[String] = []
	for other in s.cur_activated_abilities:
		if other != a and not other.effects.is_empty():
			var counted := _counted_kind(other.effects[0])
			if counted != "":
				kinds.append(counted)
	if kinds.is_empty():
		return ""
	var line: String = a.effects[0].describe().to_lower()
	if not line.begins_with("put a ") or not line.contains(" counter on this"):
		return ""
	var kind := line.substr(6).split(" ", false)[0]
	return kind if kinds.has(kind) else ""


## The blast itself: the best of THEIR face when the count is lethal, the
## creature of theirs the count kills, else nothing — the sacrifice rider
## is priced by the caller ([method AiPlayer._sacrifice_price]).
static func counter_blast_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		n: int, _window: String) -> Dictionary:
	if n <= 0:
		return {}
	var spec: TargetSpec = a.effects[0].target_spec
	var foe: int = g.opponent_of(pilot.pid)
	var face := TargetRef.player(foe)
	if spec != null and spec.is_legal(g, face, s) and n >= g.players[foe].life:
		return {"value": pilot.LETHAL_WORTH, "targets": [face]}
	var best := {}
	for i in g.players[foe].battlefield:
		if not i.is_creature() or i.cur_indestructible:
			continue
		var ref := TargetRef.card(i)
		if spec != null and not spec.is_legal(g, ref, s):
			continue
		if not bool(g.predict_damage(s, ref, n, false, 0, pilot.pid)["dies"]):
			continue
		var value: float = pilot._victim_value(g, i) + 1.0
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": [ref]}
	return best


# ------------------------------------------------------- the fight pair --

## "Target creature you control fights target creature an opponent
## controls" (Triangle of War, card batch B6): two slots, ours first. The
## pair where ours kills theirs, priced as their creature less ours when
## ours dies too; fight damage is not combat (no first strike, no
## flanking), so the arithmetic is the two powers against the two
## toughnesses, through the damage pipeline where the table shapes it.
static func fight_pair_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if window != "MAIN" and window != "RESPONSE":
		return {}
	var mine_spec: TargetSpec = a.effects[0].target_spec
	var theirs_spec: TargetSpec = a.effects[1].target_spec
	if mine_spec == null or theirs_spec == null:
		return {}
	var best := {}
	for mine in g.players[pilot.pid].battlefield:
		if not mine.is_creature() or mine.cur_power <= 0:
			continue
		var mine_ref := TargetRef.card(mine)
		if not mine_spec.is_legal(g, mine_ref, s) or dies_when_targeted(mine):
			continue
		for theirs in g.players[g.opponent_of(pilot.pid)].battlefield:
			if not theirs.is_creature():
				continue
			var their_ref := TargetRef.card(theirs)
			if not theirs_spec.is_legal(g, their_ref, s, [mine_ref]):
				continue
			if not bool(g.predict_damage(mine, their_ref, mine.cur_power, false, 0, pilot.pid)["dies"]):
				continue
			var value: float = pilot._victim_value(g, theirs) + 1.0
			if theirs.cur_power > 0 and bool(g.predict_damage(theirs, mine_ref,
					theirs.cur_power, false, 0, pilot.pid)["dies"]):
				value -= pilot._own_value(g, mine)
			if value > 0.0 and (best.is_empty() or value > float(best["value"])):
				best = {"value": value, "targets": [mine_ref, their_ref]}
	return best


# ================================================================ phasing --

## Will [param inst] phase OUT at its controller's next untap step — a
## printed or granted PHASING keyword it is not held against (CR 702.26a,
## [member CardInstance.cur_cant_phase_out])? Such a body is no attacker
## on that turn: it is gone before the combat (`_could_attack_next_turn`).
static func phases_out_before_attacking(inst: CardInstance) -> bool:
	return inst != null and not inst.phased_out \
		and inst.has_keyword(Mtg.Keyword.PHASING) and not inst.cur_cant_phase_out


## [param seat]'s creatures that phased out under its control and come
## back at ITS next untap step — before its next combat. Public (CR
## 702.26: the list is on the table for both seats).
static func returning_creatures(g: MtgGame, seat: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[seat].phased_out:
		if inst.is_creature() and inst.phase_hold < 0 and not inst.phased_indirectly:
			out.append(inst)
	return out


## The effects of [param data]'s mode [param mode] (its spell effects for a
## card without modes).
static func _mode_effects(data: CardData, mode: int) -> Array:
	if data.is_modal():
		return data.modes[clampi(mode, 0, data.modes.size() - 1)]["effects"]
	return data.spell_effects


## Does any effect of [param data] (any mode) carry [param role]?
static func carries_role(data: CardData, role: StringName) -> bool:
	var lists: Array = [data.spell_effects]
	for m in data.modes:
		lists.append(m["effects"])
	for effects in lists:
		for e in effects:
			if e.ai_role == role:
				return true
	return false


## EVERY WAY THIS SEAT CAN PHASE [param victim] OUT RIGHT NOW, cheapest
## first: `{price, kind (&"spell" or &"ability"), inst, index, mode,
## targets}`. An activated ability of ours whose first effect carries
## `phase_out` (a target — Vodalian Illusionist), `phase_out_self` (the
## victim's own — Rainbow Efreet, Mist Dragon) or `phase_out_host` (the
## Vanishing on it); or an instant-speed spell in hand with a `phase_out`
## mode that may name it (Reality Ripple, Sapphire Charm). Mana is planned
## the way the activation and the response casts plan it; a spell is
## priced as the card it is, an ability as its mana (and the body a {T}
## of another creature takes out of the combat).
static func phase_tools(g: MtgGame, pilot, victim: CardInstance) -> Array:
	var out: Array = []
	var pid: int = pilot.pid
	var sources: Array = pilot._mana_sources(g)
	var vref := TargetRef.card(victim)
	for src in g.players[pid].battlefield:
		for index in src.cur_activated_abilities.size():
			var a: ActivatedAbility = src.cur_activated_abilities[index]
			if a.effects.is_empty():
				continue
			var e: EffectBase = a.effects[0]
			var targets: Array = []
			match e.ai_role:
				&"phase_out":
					if e.target_spec == null or not e.target_spec.is_legal(g, vref, src):
						continue
					targets = [vref]
				&"phase_out_self":
					if src != victim:
						continue
				&"phase_out_host":
					if src.attached_to != victim.id:
						continue
				_:
					continue
			if not pilot._ability_available(g, src, index):
				continue
			var surcharge := g.ability_surcharge(pid, src)
			var own: Array = sources
			if a.tap_cost:
				own = sources.filter(func(row: Array) -> bool: return row[0] != src)
			if not (pilot._cost_is_free(a.cost) and surcharge == 0) \
					and pilot._plan_taps_from(own, a.cost, surcharge,
						g.ability_mana_usage_keys(src)).is_empty():
				continue
			var price := float(a.cost.mana_value()) * 0.5
			if a.tap_cost and src != victim and src.is_creature():
				price += 0.5
			out.append({"price": price, "kind": &"ability", "inst": src,
				"index": index, "mode": 0, "targets": targets})
	for inst in g.players[pid].hand:
		if not carries_role(inst.data, &"phase_out") or not g.casts_at_instant_speed(pid, inst):
			continue
		var modes: Array = range(inst.data.modes.size()) if inst.data.is_modal() else [0]
		for mode in modes:
			var hit := false
			for e in _mode_effects(inst.data, mode):
				if e.ai_role == &"phase_out" and e.target_spec != null \
						and e.target_spec.is_legal(g, vref, inst):
					hit = true
			if not hit or g.cast_refusal(pid, inst, [vref], 0, mode) != "":
				continue
			var surcharge := g.spell_surcharge(pid, inst.data)
			var cost := g.spell_cost_for(pid, inst.data, 0, mode)
			if not (pilot._cost_is_free(cost) and surcharge == 0) \
					and pilot._plan_taps_from(sources, cost, surcharge,
						g.mana_usage_keys(inst.data, inst)).is_empty():
				continue
			out.append({"price": Evaluator.card_value(inst.data), "kind": &"spell",
				"inst": inst, "index": -1, "mode": mode, "targets": [vref]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["price"]) < float(b["price"]))
	return out


## Put [param tool] (one row of [method phase_tools]) to work; the action
## line, or "" when the payment or the engine refused it.
static func use_tool(g: MtgGame, pilot, tool: Dictionary, verb: String) -> String:
	var src: CardInstance = tool["inst"]
	if tool["kind"] == &"spell":
		var cast: String = pilot._cast_response(g, src, tool["targets"], int(tool["mode"]),
			"cast %s: %s" % [src.data.card_name, verb])
		return cast
	var index := int(tool["index"])
	var a: ActivatedAbility = src.cur_activated_abilities[index]
	var pay := g.ability_payment(pilot.pid, src, index, 0)
	if not pilot._plan_and_pay(g, pay.cost, int(pay.extra), pay.usage, pilot._tap_spared(src, a)):
		return ""
	var err := g.activate_ability(pilot.pid, src, index, tool["targets"])
	if err != "":
		g.log_line("(AI activation of %s refused: %s)" % [src.data.card_name, err])
		pilot._refused["%d:%d" % [src.id, index]] = true
		return ""
	return "activated %s: %s" % [src.data.card_name, verb]


## THE RESPONSE ARM, asked by [method AiPlayer._respond_action] (which runs
## only for a seat that holds instants): one phasing action, or "".
static func respond(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	var done := save_by_phasing(g, pilot)
	if done != "":
		return done
	done = save_by_ward(g, pilot)
	if done != "":
		return done
	done = flash_ambush(g, pilot)
	if done != "":
		return done
	done = token_ambush(g, pilot)
	if done != "":
		return done
	done = aura_trick(g, pilot)
	if done != "":
		return done
	done = make_blocked_response(g, pilot)
	if done != "":
		return done
	done = shield_response(g, pilot)
	if done != "":
		return done
	done = save_from_combat(g, pilot)
	if done != "":
		return done
	done = phase_their_attacker(g, pilot)
	if done != "":
		return done
	return phase_their_blocker(g, pilot)


## THE SAVE (CR 702.26b: a phased-out permanent is not a legal target, so
## the spell aimed at it does nothing): the top of the stack is THEIRS and
## would remove, kill, steal or shrink a permanent of ours worth more than
## the cheapest way to phase it out.
static func save_by_phasing(g: MtgGame, pilot) -> String:
	if g.stack.is_empty():
		return ""
	var top: StackItem = g.stack.back()
	if top.controller == pilot.pid or top.targets.is_empty():
		return ""
	var hostile := false
	var intent: EffectIntent = null
	if top.kind == Mtg.StackKind.SPELL and top.card != null and top.card.data.is_aura():
		hostile = EffectIntent.aura_aim(top.card.data) == EffectIntent.Aim.HOSTILE
	else:
		var label: String = top.card.data.card_name if top.card != null else ""
		intent = EffectIntent.read(top.effects, label)
		hostile = intent.is_harmful() and not intent.is_tap_utility()
	if not hostile:
		return ""
	for t in top.targets:
		if t == null or t.is_player or t.is_damage or t.is_ability:
			continue
		var victim := g.find_instance(t.instance_id)
		if victim == null or victim.controller_id != pilot.pid or not g.is_present(victim):
			continue
		if dies_when_targeted(victim):
			continue   # it is already gone: its own trigger is on the stack
		if intent != null and victim.is_creature() and intent.damage_at(top.x_value) > 0 \
				and not intent.removes and not intent.bounces \
				and not intent.kills(victim, top.x_value):
			continue   # damage it lives through is no reason to spend anything
		var worth: float = pilot._own_value(g, victim)
		var tools := phase_tools(g, pilot, victim)
		if tools.is_empty() or worth < 2.0 or worth < float(tools[0]["price"]) + 0.5:
			continue
		return use_tool(g, pilot, tools[0], "phases out %s" % victim.data.card_name)
	return ""


## THE COMBAT SAVE: blocks are declared and a creature of ours dies in the
## damage about to be dealt. Phased out it leaves the combat (CR 702.26b);
## the attacker it blocked stays BLOCKED (CR 509.1h) and deals nothing to
## us, and an attacker of ours that would only have traded is kept unless
## the trade was worth more than it.
static func save_from_combat(g: MtgGame, pilot) -> String:
	if g.combat.attackers.is_empty() or g.current_step() != Mtg.Step.DECLARE_BLOCKERS \
			or g.awaiting_blockers or not g.stack.is_empty():
		return ""
	var best := {}
	var best_worth := 0.0
	var best_victim: CardInstance = null
	for inst in g.players[pilot.pid].battlefield:
		if not inst.is_creature():
			continue
		var attacking: bool = g.combat.attackers.has(inst.id)
		if not attacking and not g.combat.blocks.has(inst.id):
			continue
		if not pilot._dies_in_combat(g, inst):
			continue
		var worth: float = pilot._own_value(g, inst)
		if attacking:
			var takes := 0.0
			for blocker_id in g.combat.blockers_of(inst.id):
				var blocker := g.find_instance(blocker_id)
				if blocker != null and pilot._dies_to(g, blocker, inst):
					takes += pilot._victim_value(g, blocker)
			if takes >= worth:
				continue   # the trade stands
		var tools := phase_tools(g, pilot, inst)
		if tools.is_empty() or worth < float(tools[0]["price"]) + 1.0:
			continue
		if worth > best_worth:
			best = tools[0]
			best_worth = worth
			best_victim = inst
	if best.is_empty():
		return ""
	return use_tool(g, pilot, best, "phases out %s" % best_victim.data.card_name)


## THEIR ATTACKER, PHASED OUT BEFORE BLOCKS: it deals nothing this combat
## and, gone until ITS controller's next untap step, is no blocker on our
## next turn either. Priced as the damage it stops through our best blocks
## plus half of it as a blocker; the game when it is the lethal one.
static func phase_their_attacker(g: MtgGame, pilot) -> String:
	if g.active_player == pilot.pid or g.current_step() != Mtg.Step.DECLARE_ATTACKERS \
			or g.combat.attackers.is_empty() or not g.stack.is_empty():
		return ""
	var pid: int = pilot.pid
	var life := g.players[pid].life
	var attackers: Array[CardInstance] = pilot._declared_attackers(g)
	var blockers: Array[CardInstance] = pilot._untapped_creatures(g, pid)
	var before: int = pilot._damage_through_blocks(g, attackers, blockers, pid)
	var best := {}
	var best_value := 0.0
	var best_victim: CardInstance = null
	for attacker in attackers:
		var tools := phase_tools(g, pilot, attacker)
		if tools.is_empty():
			continue
		var rest: Array[CardInstance] = []
		for other in attackers:
			if other != attacker:
				rest.append(other)
		var after: int = pilot._damage_through_blocks(g, rest, blockers, pid)
		var value: float = float(before - after) * pilot._life_price(life) \
			+ pilot._victim_value(g, attacker) * 0.5
		if before >= life and after < life:
			value = pilot.LETHAL_WORTH
		if value < float(tools[0]["price"]) + 1.5:
			continue
		if value > best_value:
			best = tools[0]
			best_value = value
			best_victim = attacker
	if best.is_empty():
		return ""
	return use_tool(g, pilot, best, "phases out %s" % best_victim.data.card_name)


## THEIR BLOCKER, PHASED OUT AT OUR BEGINNING OF COMBAT: back at their
## untap step, so it still attacks us — the only gain is the damage our
## attack puts through without it, read through their best blocks
## ([method AiPlayer._damage_through_blocks]); the game when it is lethal.
static func phase_their_blocker(g: MtgGame, pilot) -> String:
	if g.active_player != pilot.pid or g.current_step() != Mtg.Step.COMBAT_BEGIN \
			or not g.stack.is_empty():
		return ""
	var foe: int = g.opponent_of(pilot.pid)
	var attackers: Array[CardInstance] = pilot._attack_candidates(g, foe)
	var blockers: Array[CardInstance] = pilot._untapped_creatures(g, foe)
	if attackers.is_empty() or blockers.is_empty():
		return ""
	var their_life := g.players[foe].life
	var before: int = pilot._damage_through_blocks(g, attackers, blockers, foe)
	var best := {}
	var best_value := 0.0
	var best_victim: CardInstance = null
	for blocker in blockers:
		var tools := phase_tools(g, pilot, blocker)
		if tools.is_empty():
			continue
		var rest: Array[CardInstance] = []
		for other in blockers:
			if other != blocker:
				rest.append(other)
		var after: int = pilot._damage_through_blocks(g, attackers, rest, foe)
		if after <= before:
			continue
		var value: float = pilot._face_damage_value(g, after - before, foe)
		if before < their_life and after >= their_life:
			value = pilot.LETHAL_WORTH
		if value < float(tools[0]["price"]) + 1.0:
			continue
		if value > best_value:
			best = tools[0]
			best_value = value
			best_victim = blocker
	if best.is_empty():
		return ""
	return use_tool(g, pilot, best, "phases out %s" % best_victim.data.card_name)


## THE MAIN-PHASE CAST of a card with a phasing role, asked by [method
## AiPlayer._size_and_aim] for mode [param mode]: null when the mode has
## no such role. A targeted phase-out is a COMBAT tool: a seat that holds
## instants keeps it for the moments [method respond] reads ({}); one that
## does not (the Apprentice's sorcery-speed game) casts it in its first
## main phase at the blocker whose absence opens the most damage, or not
## at all. Time and Tide is priced by [method phase_swap_value].
static func spell_choice(g: MtgGame, pilot, inst: CardInstance, mode: int) -> Variant:
	if not pilot.profile.forecasts_tactics:
		return null
	# A "SOURCE OF YOUR CHOICE" SHIELD is a RESPONSE (the Pack 8 duel
	# audit: Reflect Damage cast six times in our own main phase, naming a
	# land, stopping nothing): never the main planner's ([method
	# shield_response] casts it).
	if is_shield_spell(inst.data):
		return {}
	# A TOKEN GONE AT THE NEXT END STEP is never the main planner's in our
	# own turn (the bug pass, 2026-10-04: Tidal Wave's Wall cast in our main
	# phase, unable to attack and sacrificed at our end step): its moment
	# is their attack ([method token_ambush]). A hasty token is an attack.
	var doomed := doomed_token(inst.data)
	if doomed != null and g.active_player == pilot.pid \
			and not doomed.has_keyword(Mtg.Keyword.HASTE):
		return {}
	if not inst.data.is_modal():
		var lock: Variant = lock_choice(g, pilot, inst)
		if lock != null:
			return lock
		var chosen: Variant = role_choice(g, pilot, inst)
		if chosen != null:
			return chosen
	var effects := _mode_effects(inst.data, mode)
	var role: StringName = &""
	for e in effects:
		if e.ai_role in [&"phase_out", &"phase_swap"]:
			role = e.ai_role
	if role == &"":
		return null
	if role == &"phase_swap":
		var swing := phase_swap_value(g, pilot)
		return {} if swing < 2.5 else {"x": 0, "targets": [], "value": swing}
	if pilot.profile.holds_instants and g.casts_at_instant_speed(pilot.pid, inst):
		return {}
	if g.current_step() != Mtg.Step.MAIN1 or g.active_player != pilot.pid:
		return {}
	var foe: int = g.opponent_of(pilot.pid)
	var attackers: Array[CardInstance] = pilot._attack_candidates(g, foe)
	var blockers: Array[CardInstance] = pilot._untapped_creatures(g, foe)
	if attackers.is_empty() or blockers.is_empty():
		return {}
	var spec: TargetSpec = null
	for e in effects:
		if e.ai_role == &"phase_out":
			spec = e.target_spec
	var before: int = pilot._damage_through_blocks(g, attackers, blockers, foe)
	var best := {}
	for blocker in blockers:
		var ref := TargetRef.card(blocker)
		if spec == null or not spec.is_legal(g, ref, inst):
			continue
		var rest: Array[CardInstance] = []
		for other in blockers:
			if other != blocker:
				rest.append(other)
		var after: int = pilot._damage_through_blocks(g, attackers, rest, foe)
		if after <= before:
			continue
		var value: float = pilot._face_damage_value(g, after - before, foe)
		if before < g.players[foe].life and after >= g.players[foe].life:
			value = pilot.LETHAL_WORTH
		if value > Evaluator.card_value(inst.data) and (best.is_empty() or value > float(best["value"])):
			best = {"x": 0, "targets": [ref], "value": value}
	return best


## TIME AND TIDE'S SWING ("simultaneously, all phased-out creatures phase
## in and all creatures with phasing phase out"): what each side gets back
## less what each side sends away, our side counted for us. A present
## phaser sent away comes back at its controller's next untap step, so it
## is half a loss.
static func phase_swap_value(g: MtgGame, pilot) -> float:
	var pid: int = pilot.pid
	var swing := 0.0
	for seat in [pid, g.opponent_of(pid)]:
		var sign := 1.0 if seat == pid else -1.0
		for inst in returning_creatures(g, seat):
			swing += sign * Evaluator.permanent_value(inst, null)
		for inst in g.players[seat].battlefield:
			if inst.is_creature() and inst.has_keyword(Mtg.Keyword.PHASING) \
					and not inst.cur_cant_phase_out:
				swing -= sign * Evaluator.permanent_value(inst, null) * 0.5
	return swing


## A SWEEPER WAITS while more of what it would take is phased out than is
## present (Pack 8): the creatures come back at their controller's untap
## step, and a Wrath now takes the one in front of it and misses the two
## behind. Never while we are in danger.
static func sweep_waits_for_phasers(g: MtgGame, pilot, effect: EffectBase, n: int) -> bool:
	if not pilot.profile.forecasts_tactics or pilot._in_danger(g):
		return false
	var foe: int = g.opponent_of(pilot.pid)
	var away := 0.0
	for inst in returning_creatures(g, foe):
		if pilot._sweep_kills(effect, inst, n):
			away += Evaluator.permanent_value(inst, null)
	if away <= 0.0:
		return false
	var here := 0.0
	for inst in g.players[foe].battlefield:
		if inst.is_creature() and pilot._sweep_kills(effect, inst, n):
			here += Evaluator.permanent_value(inst, null)
	return away > here


# ================================================================== flash --

## Does [param inst], a creature card in hand, wait out OUR main phase
## for their turn (Pack 8, 2026-10-03)? A creature with flash (the
## keyword, a flash rider, a seat grant — [method MtgGame.has_flash]) that
## would only be summoning-sick until our next turn anyway is worth more
## held: an ambush blocker after their attackers are declared ([method
## flash_ambush]), or else deployed at their end step ([method
## end_step_flash]) with the mana it kept open threatening all turn. A
## HASTE creature attacks today and is cast as it always was. Its mana is
## booked like a held instant's ([method AiPlayer._held_reserve]).
static func flash_creature_waits(g: MtgGame, pilot, inst: CardInstance) -> bool:
	if not pilot.profile.forecasts_tactics or not pilot.profile.holds_instants:
		return false
	if not inst.data.is_creature() or inst.data.is_aura() or g.active_player != pilot.pid:
		return false
	if inst.data.has_keyword(Mtg.Keyword.HASTE):
		return false
	# Only the card's OWN flash waits: a seat's grant (Winding Canyons,
	# "this turn") is gone by their turn.
	if not inst.data.has_keyword(Mtg.Keyword.FLASH) and not inst.has_keyword(Mtg.Keyword.FLASH):
		return false
	# THE HOLD MUST BE WORTH ITS TEMPO (the matched Deck Lab study,
	# 2026-10-03: holding every flash creature for their turn measured
	# -14.5 +-9.3 on the Flash deck against the Costs deck — the body
	# missed the blocks it would have made from our main phase, and its
	# booked mana held other casts back). A flash creature waits only
	# when THEIR board offers the ambush ([method _ambush_read]: a
	# creature that can attack us next turn which it would block, kill
	# and survive) and nothing else in our hand wants the mana now.
	var pid: int = pilot.pid
	var ambush := false
	for theirs in g.players[g.opponent_of(pid)].battlefield:
		if not theirs.is_creature() or not pilot._could_attack_next_turn(g, theirs):
			continue
		var read := _ambush_read(inst.data, theirs)
		if bool(read["blocks"]) and bool(read["kills"]) and bool(read["lives"]):
			ambush = true
			break
	if not ambush:
		return false
	var sources: Array = pilot._mana_sources(g)
	for other in g.players[pid].hand:
		if other == inst or other.is_land() or pilot._refused.has(str(other.id)) \
				or pilot._cast_gate(g, other) != "":
			continue
		if other.data.has_keyword(Mtg.Keyword.FLASH) or other.data.flash_rider:
			continue   # also a card for their turn
		var surcharge := g.spell_surcharge(pid, other.data)
		if (pilot._cost_is_free(other.data.cost) and surcharge == 0) \
				or not pilot._plan_taps_from(sources, other.data.cost, surcharge,
					g.mana_usage_keys(other.data, other)).is_empty():
			return false   # another card wants the mana now: the body goes down
	return true


## Does [param inst], a flash-rider Aura that pumps its host, wait out OUR
## FIRST main phase (the Pack 8 duel audit: ten such Auras cast, every one
## at sorcery speed, never as a trick)? While a combat of ours is still
## ahead it stays in hand with its mana booked ([method
## AiPlayer._held_reserve]): the combat casts it where it wins or saves a
## fight ([method aura_trick]), and the second main phase casts it for
## its permanent value as it always did.
static func trick_aura_waits(g: MtgGame, pilot, inst: CardInstance) -> bool:
	if not pilot.profile.forecasts_tactics or not pilot.profile.holds_instants:
		return false
	if not inst.data.is_aura() or not inst.data.flash_rider:
		return false
	var bonus := aura_pump(inst.data)
	if bonus.x <= 0 and bonus.y <= 0:
		return false
	if g.active_player != pilot.pid or g.current_step() != Mtg.Step.MAIN1:
		return false
	# Only while a BLOCK can come (the Deck Lab study): with nothing of
	# theirs to block one of our attackers, no trick will be wanted, and
	# the Aura goes on for keeps before the attack it then improves.
	var foe: int = g.opponent_of(pilot.pid)
	for attacker in pilot._attack_candidates(g, foe):
		if pilot._blockable_by_any(g, attacker, foe):
			return true
	return false


## The +P/+T of the best flash-rider pump Aura in hand that could be cast
## at instant speed and paid for now — the trick the attack rider of
## [method AiPlayer._attack_choice] may count on, as it counts a Giant
## Growth; ZERO when there is none.
static func trick_aura_bonus(g: MtgGame, pilot) -> Vector2i:
	var inst := trick_aura_in_hand(g, pilot)
	return Vector2i.ZERO if inst == null else aura_pump(inst.data)


## The flash-rider pump Aura in hand [method trick_aura_bonus] reads, or
## null: the largest lift that could be cast at instant speed and paid now.
static func trick_aura_in_hand(g: MtgGame, pilot) -> CardInstance:
	var pid: int = pilot.pid
	var sources: Array = pilot._mana_sources(g)
	var best: CardInstance = null
	var best_sum := 0
	for inst in g.players[pid].hand:
		if not inst.data.is_aura() or not inst.data.flash_rider or not g.has_flash(pid, inst) \
				or pilot._refused.has(str(inst.id)) or pilot._cast_gate(g, inst) != "":
			continue
		var bonus := aura_pump(inst.data)
		if bonus.y <= 0 or bonus.x + bonus.y <= best_sum:
			continue
		if pilot._plan_taps_from(sources, inst.data.cost, g.spell_surcharge(pid, inst.data),
				g.mana_usage_keys(inst.data, inst)).is_empty():
			continue
		best = inst
		best_sum = bonus.x + bonus.y
	return best


## The best flash creature in hand castable and payable right now, as
## `{inst, value}`, or {}.
static func _flash_creature_in_hand(g: MtgGame, pilot) -> Dictionary:
	var pid: int = pilot.pid
	var sources: Array = pilot._mana_sources(g)
	var best := {}
	for inst in g.players[pid].hand:
		if not inst.data.is_creature() or inst.data.is_aura() \
				or not g.casts_at_instant_speed(pid, inst) or pilot._refused.has(str(inst.id)):
			continue
		var surcharge := g.spell_surcharge(pid, inst.data)
		if not (pilot._cost_is_free(inst.data.cost) and surcharge == 0) \
				and pilot._plan_taps_from(sources, inst.data.cost, surcharge,
					g.mana_usage_keys(inst.data, inst)).is_empty():
			continue
		var value: float = pilot._card_value(inst.data)
		if best.is_empty() or value > float(best["value"]):
			best = {"inst": inst, "value": value}
	return best


## THEIR END STEP: the flash creature that waited is deployed now, with
## mana the untap step would otherwise waste. Asked by [method
## AiPlayer._end_of_their_turn] after the held instants have had theirs.
static func end_step_flash(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics or g.active_player == pilot.pid \
			or g.current_step() != Mtg.Step.END or not g.stack.is_empty():
		return ""
	var best := _flash_creature_in_hand(g, pilot)
	if best.is_empty():
		return ""
	var inst: CardInstance = best["inst"]
	return pilot._cast_response(g, inst, [], 0, "cast %s at end of turn" % inst.data.card_name)


## Could [param body] — a creature card not yet on the battlefield, its
## PRINTED numbers — block [param attacker], kill it and live? The flying
## rule is the one evasion a hand card can be read against; first strike
## decides who strikes first. `{kills, lives}`.
static func _ambush_read(body: CardData, attacker: CardInstance) -> Dictionary:
	var out := {"blocks": true, "kills": false, "lives": false}
	if attacker.has_keyword(Mtg.Keyword.FLYING) and not body.has_keyword(Mtg.Keyword.FLYING) \
			and not body.has_keyword(Mtg.Keyword.REACH):
		out["blocks"] = false
		return out
	if attacker.has_keyword(Mtg.Keyword.UNBLOCKABLE) or (attacker.cur_protection & body.color_mask()) != 0:
		out["blocks"] = false
		return out
	var kills := body.power >= attacker.cur_toughness - attacker.damage \
		and not attacker.cur_indestructible
	var first := body.has_keyword(Mtg.Keyword.FIRST_STRIKE) \
		and not attacker.has_keyword(Mtg.Keyword.FIRST_STRIKE)
	out["kills"] = kills
	out["lives"] = attacker.cur_power < body.toughness or (first and kills)
	return out


## THE AMBUSH: their attackers are declared, our blocks are not; a flash
## creature cast now blocks one of them. Worth it when it kills an attacker
## and lives, or when it is the blocker that turns a lethal attack into a
## survived one. Otherwise it waits for their end step.
static func flash_ambush(g: MtgGame, pilot) -> String:
	if g.active_player == pilot.pid or g.current_step() != Mtg.Step.DECLARE_ATTACKERS \
			or g.combat.attackers.is_empty() or not g.stack.is_empty():
		return ""
	var best := _flash_creature_in_hand(g, pilot)
	if best.is_empty():
		return ""
	var inst: CardInstance = best["inst"]
	var pid: int = pilot.pid
	var life := g.players[pid].life
	var attackers: Array[CardInstance] = pilot._declared_attackers(g)
	var before: int = pilot._damage_through_blocks(g, attackers, pilot._untapped_creatures(g, pid), pid)
	var value := 0.0
	for attacker in attackers:
		var read := _ambush_read(inst.data, attacker)
		if not bool(read["blocks"]):
			continue
		if bool(read["kills"]) and bool(read["lives"]):
			value = maxf(value, pilot._victim_value(g, attacker) + 1.0)
		if before >= life and before - maxi(attacker.cur_power, 0) < life:
			value = pilot.LETHAL_WORTH
	if value < 3.0:
		return ""
	return pilot._cast_response(g, inst, [], 0, "cast %s as a surprise blocker" % inst.data.card_name)


## The +P/+T an Aura's own line prints for its host ("Enchanted creature
## gets +2/+2"), read off the oracle text the way [method
## EffectIntent.aura_gifts] reads its keywords; ZERO when it prints none.
static func aura_pump(data: CardData) -> Vector2i:
	# One line of the oracle ends at a newline, not a space (Coils of the
	# Medusa's "+1/-1.\nSacrifice this Aura: ..." read as no pump at all).
	var lower := data.oracle_text.to_lower().replace("\n", " ")
	var at := lower.find("enchanted creature gets ")
	if at < 0:
		return Vector2i.ZERO
	var rest := lower.substr(at + 24).split(" ", false)
	if rest.is_empty():
		return Vector2i.ZERO
	var pt := rest[0].trim_suffix(".").split("/")
	if pt.size() != 2 or not pt[0].is_valid_int() or not pt[1].is_valid_int():
		return Vector2i.ZERO
	return Vector2i(int(pt[0]), int(pt[1]))


## THE ONE-TURN TRICK: blocks are declared and a flash-rider Aura cast now
## — sacrificed at the next cleanup step, `memory["flash_cast"]` — turns a
## combat of ours: the creature it lifts survives where it would have
## died, or kills where it would not have. Priced as the whole card, since
## nothing of it is left after the turn.
static func aura_trick(g: MtgGame, pilot) -> String:
	if g.combat.attackers.is_empty() or g.current_step() != Mtg.Step.DECLARE_BLOCKERS \
			or g.awaiting_blockers or not g.stack.is_empty():
		return ""
	var pid: int = pilot.pid
	var sources: Array = pilot._mana_sources(g)
	var best := {}
	for inst in g.players[pid].hand:
		if not inst.data.is_aura() or not inst.data.flash_rider \
				or not g.casts_at_instant_speed(pid, inst) or pilot._refused.has(str(inst.id)):
			continue
		var bonus := aura_pump(inst.data)
		if bonus.x <= 0 and bonus.y <= 0:
			continue
		var surcharge := g.spell_surcharge(pid, inst.data)
		if pilot._plan_taps_from(sources, inst.data.cost, surcharge,
				g.mana_usage_keys(inst.data, inst)).is_empty():
			continue
		var price: float = Evaluator.card_value(inst.data)
		for ours in g.players[pid].battlefield:
			if not ours.is_creature() or dies_when_targeted(ours):
				continue
			# Its own -N toughness would kill the body before the damage
			# step (the bug pass: Grave Servitude's +3/-1 on a 1/1).
			if ours.cur_toughness + bonus.y <= ours.damage:
				continue
			var ref := TargetRef.card(ours)
			if inst.data.aura_target == null or not inst.data.aura_target.is_legal(g, ref, inst):
				continue
			var foes: Array = []
			if g.combat.attackers.has(ours.id):
				foes = g.combat.blockers_of(ours.id)
			elif g.combat.blocks.has(ours.id):
				foes = g.combat.attackers_blocked_by(ours.id)
			if foes.is_empty():
				continue
			var gain := 0.0
			var died := false
			var lives := true
			for foe_id in foes:
				var foe := g.find_instance(foe_id)
				if foe == null or not g.is_present(foe):
					continue
				if pilot._dies_to(g, ours, foe):
					died = true
				if pilot._dies_to(g, ours, foe, bonus):
					lives = false
				if not pilot._dies_to(g, foe, ours) and pilot._dies_to(g, foe, ours, Vector2i.ZERO, bonus):
					gain += pilot._victim_value(g, foe)
			if died and lives:
				gain += pilot._own_value(g, ours)
			gain -= price
			if gain > 0.5 and (best.is_empty() or gain > float(best["value"])):
				best = {"inst": inst, "targets": [ref], "value": gain}
	if best.is_empty():
		return ""
	var aura: CardInstance = best["inst"]
	return pilot._cast_response(g, aura, best["targets"], 0,
		"cast %s as a combat trick" % aura.data.card_name)


## THE WARD: the top of the stack is a hostile spell or ability of theirs
## aimed at a permanent of ours, and a flash-rider Aura in hand would make
## that target illegal — shroud ("has shroud": Mystic Veil, Relic Ward) or
## protection from the colour the Aura names as it enters (Ward of Lights,
## whose own colour hint reads the threat on the stack). The Aura is gone
## at cleanup; it was bought for this.
static func save_by_ward(g: MtgGame, pilot) -> String:
	if g.stack.is_empty():
		return ""
	var top: StackItem = g.stack.back()
	if top.controller == pilot.pid or top.targets.is_empty() or top.card == null:
		return ""
	var hostile := false
	var intent: EffectIntent = null
	if top.kind == Mtg.StackKind.SPELL and top.card.data.is_aura():
		hostile = EffectIntent.aura_aim(top.card.data) == EffectIntent.Aim.HOSTILE
	else:
		intent = EffectIntent.read(top.effects, top.card.data.card_name)
		hostile = intent.is_harmful() and not intent.is_tap_utility()
	if not hostile:
		return ""
	var colours: int = top.card.cur_colors & (Mtg.ManaColor.W | Mtg.ManaColor.U
		| Mtg.ManaColor.B | Mtg.ManaColor.R | Mtg.ManaColor.G)
	var pid: int = pilot.pid
	var sources: Array = pilot._mana_sources(g)
	for t in top.targets:
		if t == null or t.is_player or t.is_damage or t.is_ability:
			continue
		var victim := g.find_instance(t.instance_id)
		if victim == null or victim.controller_id != pid or not g.is_present(victim) \
				or dies_when_targeted(victim):
			continue
		if intent != null and victim.is_creature() and intent.damage_at(top.x_value) > 0 \
				and not intent.removes and not intent.bounces \
				and not intent.kills(victim, top.x_value):
			continue
		var worth: float = pilot._own_value(g, victim)
		for inst in g.players[pid].hand:
			if not inst.data.is_aura() or not inst.data.flash_rider \
					or not g.casts_at_instant_speed(pid, inst):
				continue
			var lower := inst.data.oracle_text.to_lower()
			var shroud := lower.contains("has shroud")
			var ward := colours != 0 and (inst.data.aura_protection_memory_key != ""
				or (inst.data.aura_grants_protection & colours) != 0)
			if not shroud and not ward:
				continue
			var ref := TargetRef.card(victim)
			if inst.data.aura_target == null or not inst.data.aura_target.is_legal(g, ref, inst):
				continue
			if worth < Evaluator.card_value(inst.data) + 0.5:
				continue
			if pilot._plan_taps_from(sources, inst.data.cost, g.spell_surcharge(pid, inst.data),
					g.mana_usage_keys(inst.data, inst)).is_empty():
				continue
			var cast: String = pilot._cast_response(g, inst, [ref], 0,
				"cast %s to save %s" % [inst.data.card_name, victim.data.card_name])
			if cast != "":
				return cast
	return ""


# ================================================== flanking's leftovers --

## The flanking triggers still ON THE STACK that will shrink [param
## blocker] (CR 702.25: one per instance per blocking creature, each a
## -1/-1 when it resolves). The combat maths counted a resolved one — it
## is in the live numbers — and a planned one ([method
## AiPlayer._flank_pair]), but not the one between the declaration and
## its resolution, which is when every response to the block is made.
static func pending_flank(g: MtgGame, blocker: CardInstance) -> int:
	if blocker == null:
		return 0
	var shared: TriggeredAbility = g.continuous.flanking_trigger
	var n := 0
	for item in g.stack:
		if item.kind != Mtg.StackKind.TRIGGER or item.trigger != shared:
			continue
		var context: Dictionary = item.cost_paid.get("_trigger_context", {})
		if int(context.get("blocker", -1)) == blocker.id \
				and int(context.get("stamp", -1)) == blocker.layer_timestamp:
			n += 1
	return n


## THE FORCED COMPANION (CR 508.1d; Ekundu Cyclops, engine package E9):
## a creature that "attacks if able when a creature you control attacks"
## is added to any non-empty declaration by the engine's repair, and the
## cohort planner never priced it. Asked by [method
## AiPlayer._declare_attacks] with the planned [param attackers] (ids):
## when the forced bodies turn the whole attack into a loss (the
## cohort's own reading, [method AiPlayer._cohort_value]), nobody
## attacks; otherwise the plan stands and the repair brings them.
static func price_forced_attackers(g: MtgGame, pilot, attackers: Array, defender: int) -> Array:
	if attackers.is_empty() or not pilot.profile.reads_gaze:
		return attackers
	var forced: Array[CardInstance] = []
	for i in preload("res://engine/core/combat_declaration.gd").conditional_attackers(g, pilot.pid):
		if not attackers.has(i.id):
			forced.append(i)
	if forced.is_empty():
		return attackers
	for id in attackers:
		var inst := g.find_instance(id)
		if inst != null and (pilot._conscripted(g, inst) or AiPlayer._must_attack(inst)):
			return attackers   # someone attacks anyway: the companion comes regardless
	var group: Array[CardInstance] = []
	for id in attackers:
		var inst := g.find_instance(id)
		if inst != null:
			group.append(inst)
	group.append_array(forced)
	var blockers: Array[CardInstance] = pilot._untapped_creatures(g, defender)
	if float(pilot._cohort_value(g, group, blockers, defender)) < 0.0:
		return []
	return attackers


## THE LIFE TAX ON A BLOCK (Heat Wave, engine package E9: "nonblue
## creatures can't block creatures you control unless their controller
## pays 1 life for each blocking creature"). The block ladder never priced
## it — [method CombatDeclaration.repair_blocks] only keeps the total
## payable and off the last point. A taxed block is kept when it kills an
## attacker, when it stops more damage than the life it costs, or when it
## is part of surviving the attack; otherwise the life is not spent.
static func price_block_tax(g: MtgGame, pilot, block_map: Dictionary) -> Dictionary:
	if block_map.is_empty() or not pilot.profile.reads_gaze:
		return block_map
	var out := block_map.duplicate(true)
	var life := g.players[pilot.pid].life
	var through_all := 0
	for id in g.combat.attackers:
		var a := g.find_instance(id)
		if a != null and g.is_present(a):
			through_all += maxi(a.cur_power, 0)
	for blocker_id in block_map.keys():
		var blocker := g.find_instance(int(blocker_id))
		var value: Variant = block_map[blocker_id]
		var targets: Array = value if value is Array else [value]
		var against: Array = []
		for t in targets:
			against.append(g.find_instance(int(t)))
		var owed := CombatState.block_life_owed(blocker, against)
		if owed <= 0:
			continue
		var keep := false
		var stopped := 0
		for a in against:
			if a == null:
				continue
			if pilot._dies_to(g, a, blocker):
				keep = true
			var alone := true
			for other_id in block_map.keys():
				if other_id == blocker_id:
					continue
				var other: Variant = block_map[other_id]
				var others: Array = other if other is Array else [other]
				if others.has(a.id) or others.has(int(a.id)):
					alone = false
			if alone and not a.has_keyword(Mtg.Keyword.TRAMPLE):
				stopped += maxi(a.cur_power, 0)
		if stopped > owed or through_all >= life:
			keep = true
		if not keep:
			out.erase(blocker_id)
	return out


## THE BLOCK AN EFFECT MAKES (CR 509.1h; Dazzling Beauty, Choking Vines —
## [MakeBlockedEffect]): their blocks are in and an attacker of theirs is
## still unblocked. Made blocked, it deals no combat damage — unless it
## tramples, when ALL of it goes to us (CR 702.19e), so a trampler is
## never named. Choking Vines' "1 damage to each" is a kill where it
## kills. Worth the card when the damage stopped (at our life's price)
## and the kills cover it, or when it is the difference between dying and
## not.
static func make_blocked_response(g: MtgGame, pilot) -> String:
	if g.active_player == pilot.pid or g.current_step() != Mtg.Step.DECLARE_BLOCKERS \
			or g.awaiting_blockers or g.combat.attackers.is_empty() or not g.stack.is_empty():
		return ""
	var pid: int = pilot.pid
	var life := g.players[pid].life
	var unblocked_power := 0
	for id in g.combat.attackers:
		var a := g.find_instance(id)
		if a != null and g.is_present(a) and not g.combat.was_blocked(g.combat.band_of(id)):
			unblocked_power += maxi(a.cur_power, 0)
	var best := {}
	for inst in g.players[pid].hand:
		if inst.data.spell_effects.is_empty() or not (inst.data.spell_effects[0] is MakeBlockedEffect):
			continue
		if not g.casts_at_instant_speed(pid, inst) or pilot._refused.has(str(inst.id)):
			continue
		var e: MakeBlockedEffect = inst.data.spell_effects[0]
		var rows: Array = []
		for id in g.combat.attackers:
			var a := g.find_instance(id)
			if a == null or not g.is_present(a):
				continue
			var ref := TargetRef.card(a)
			if not e.target_spec.is_legal(g, ref, inst):
				continue
			var worth := 0.0
			var stops := 0
			if not g.combat.was_blocked(g.combat.band_of(id)):
				if a.has_keyword(Mtg.Keyword.TRAMPLE):
					continue
				stops = maxi(a.cur_power, 0)
				worth += float(stops) * pilot._life_price(life)
			if e.damage_each > 0 and bool(g.predict_damage(inst, ref, e.damage_each, false, 1, pid)["dies"]):
				worth += pilot._victim_value(g, a)
			if worth > 0.0:
				rows.append({"ref": ref, "worth": worth, "stops": stops})
		if rows.is_empty():
			continue
		rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["worth"]) > float(y["worth"]))
		var x_count := 1
		if e.target_count_is_x:
			var sources: Array = pilot._mana_sources(g)
			x_count = mini(rows.size(), pilot._max_affordable_x(g, inst.data.cost,
				g.spell_surcharge(pid, inst.data), sources, inst.data.x_color,
				g.mana_usage_keys(inst.data, inst)))
			if x_count <= 0:
				continue
		var targets: Array = []
		var value := 0.0
		var stopped := 0
		for i in mini(x_count, rows.size()):
			targets.append(rows[i]["ref"])
			value += float(rows[i]["worth"])
			stopped += int(rows[i]["stops"])
		if unblocked_power >= life and unblocked_power - stopped < life:
			value = pilot.LETHAL_WORTH
		value -= Evaluator.card_value(inst.data)
		if value > 0.0 and (best.is_empty() or value > float(best["value"])):
			best = {"inst": inst, "targets": targets, "value": value,
				"x": targets.size() if e.target_count_is_x else 0}
	if best.is_empty():
		return ""
	var card: CardInstance = best["inst"]
	return pilot._cast_response(g, card, best["targets"], 0,
		"cast %s: their attack is blocked" % card.data.card_name, int(best["x"]))


# ------------------------------------------------- the flankers' buttons --

## SEARING SPEAR ASKARI: "{1}{R}: This creature gains menace until end of
## turn" — bought after our attackers are declared and before their
## blocks, when exactly one creature of theirs could block it: menace
## (CR 702.110b) then leaves it unblocked. Priced as its damage through,
## and as the body itself when that one blocker would have killed it.
static func menace_option(g: MtgGame, pilot, s: CardInstance, window: String) -> Dictionary:
	if window != "RESPONSE" or g.active_player != pilot.pid \
			or g.current_step() != Mtg.Step.DECLARE_ATTACKERS or g.awaiting_attackers \
			or not g.combat.attackers.has(s.id) or s.cur_min_blockers >= 2:
		return {}
	var foe: int = g.opponent_of(pilot.pid)
	var able: Array[CardInstance] = []
	for b in pilot._untapped_creatures(g, foe):
		if CombatState.block_illegality(g, b, s, foe, true, pilot.pid) == "":
			able.append(b)
	if able.size() != 1:
		return {}
	var value: float = pilot._face_damage_value(g, maxi(s.cur_power, 0), foe)
	if pilot._dies_to(g, s, able[0]):
		value += pilot._own_value(g, s)
	# Combat mana answers to a bar of its own: the reserve check of
	# [method AiPlayer._try_activate] still keeps a held card's mana.
	return {"value": value, "targets": [], "bar": 1.0}


## KNIGHT OF VALOR: "{1}{W}: Each creature without flanking blocking this
## creature gets -1/-1 until end of turn" — bought once its blockers are
## known, when the shrink kills a blocker that would have lived or keeps
## the Knight alive. Priced as what it kills and what it saves.
static func valor_option(g: MtgGame, pilot, s: CardInstance, window: String) -> Dictionary:
	if window != "RESPONSE" or g.current_step() != Mtg.Step.DECLARE_BLOCKERS \
			or g.awaiting_blockers or not g.combat.attackers.has(s.id):
		return {}
	var blockers: Array = g.combat.blockers_of(s.id)
	if blockers.is_empty():
		return {}
	var value := 0.0
	var dies_before := false
	var dies_after := false
	var shrink := Vector2i(-1, -1)
	for id in blockers:
		var b := g.find_instance(id)
		if b == null or not g.is_present(b) or Flanking.instances(b) > 0:
			continue
		if not pilot._dies_to(g, b, s) and pilot._dies_to(g, b, s, shrink):
			value += pilot._victim_value(g, b)
		if pilot._dies_to(g, s, b):
			dies_before = true
		if pilot._dies_to(g, s, b, Vector2i.ZERO, shrink):
			dies_after = true
	if dies_before and not dies_after:
		value += pilot._own_value(g, s)
	return {} if value <= 0.0 else {"value": value, "targets": []}


# ================================================== the damage suite (E5) --

## Can the table change what combat damage does to [param victim] beyond
## what [method AiPlayer._damage_after_prevention] already reads (its
## protection, its creature/combat prevention)? A damage-replacement entry
## on the table — Blind Fury's doubling, an Inner Sanctum, Lichenthrope's
## counters — or Ogre Enforcer's single-source rule. Cheap: the combat
## maths asks it n x m times.
static func combat_damage_is_shaped(g: MtgGame, victim: CardInstance) -> bool:
	return not g.damage_effects.is_empty() or not g.static_damage_effects.is_empty() \
		or (victim != null and victim.cur_lethal_needs_single_source)


## THE SOURCE SHIELD (Circle of Despair, Honorable Passage, Shadowbane,
## Kithkin Armor, Reflect Damage — [SourceShieldEffect]), the Circle of
## Protection's answer generalised to any victim the shield covers: does
## [param e] (owned by [param src]) cover [param victim] for seat
## [param pid]?
static func shield_covers(g: MtgGame, e: SourceShieldEffect, src: CardInstance,
		victim: TargetRef, pid: int) -> bool:
	if e.action == SourceShieldEffect.Action.DOUBLE:
		return false
	match e.victims:
		SourceShieldEffect.Victims.TARGET:
			return e.target_spec != null and e.target_spec.is_legal(g, victim, src)
		SourceShieldEffect.Victims.YOU:
			return victim.is_player and victim.player_id == pid
		SourceShieldEffect.Victims.YOU_AND_YOUR_CREATURES:
			if victim.is_player:
				return victim.player_id == pid
			var inst := g.find_instance(victim.instance_id)
			return inst != null and inst.controller_id == pid
		SourceShieldEffect.Victims.ENCHANTED:
			return not victim.is_player and src.attached_to == victim.instance_id
		SourceShieldEffect.Victims.ANY:
			return true
	return false


## Is every effect of [param data] a "source of your choice" shield — a
## [SourceShieldEffect] or a modern-form [PreventDamageShieldEffect]?
static func is_shield_spell(data: CardData) -> bool:
	if data.spell_effects.is_empty():
		return false
	for e in data.spell_effects:
		if not (e is SourceShieldEffect or e is PreventDamageShieldEffect):
			return false
	return true


## May [param e] (a shield on [param src]) name [param threat] as its
## source? Its own filter — "a source you control", "a red source", the
## Circle's chosen colour — read off the effect.
static func shield_may_name(g: MtgGame, e: EffectBase, src: CardInstance,
		threat: CardInstance, pid: int) -> bool:
	if threat == null:
		return true
	if e is SourceShieldEffect:
		return e._accepts(threat, g, pid)
	if e is PreventDamageShieldEffect:
		var mask := int(src.memory.get("circle_color", 0))
		if mask != 0:
			return (mask & g.damage_source_colors(threat)) != 0
		return e._source_qualifies(threat, g)
	return true


## Every shield this seat can raise over [param victim] right now,
## cheapest first: `{price, kind, inst, index, targets}` — an instant in
## hand or an activated ability of ours (a sacrifice rider priced by
## [method AiPlayer._sacrifice_price]).
static func shield_tools(g: MtgGame, pilot, victim: TargetRef,
		threat: CardInstance = null) -> Array:
	var out: Array = []
	var pid: int = pilot.pid
	var sources: Array = pilot._mana_sources(g)
	for inst in g.players[pid].hand:
		if inst.data.spell_effects.size() != 1 or not (inst.data.spell_effects[0] is SourceShieldEffect):
			continue
		if not g.casts_at_instant_speed(pid, inst) or pilot._refused.has(str(inst.id)):
			continue
		var e: SourceShieldEffect = inst.data.spell_effects[0]
		if not shield_covers(g, e, inst, victim, pid) or not shield_may_name(g, e, inst, threat, pid):
			continue
		var targets: Array = [victim] if e.target_spec != null else []
		if g.cast_refusal(pid, inst, targets) != "":
			continue
		var surcharge := g.spell_surcharge(pid, inst.data)
		if not (pilot._cost_is_free(inst.data.cost) and surcharge == 0) \
				and pilot._plan_taps_from(sources, inst.data.cost, surcharge,
					g.mana_usage_keys(inst.data, inst)).is_empty():
			continue
		# A shield's whole job is this moment: priced at its mana, plus a
		# point for the card — never at a printed worth it has no other
		# use for.
		out.append({"price": float(inst.data.cost.mana_value()) * 0.5 + 1.0,
			"kind": &"spell", "inst": inst, "index": -1, "mode": 0, "targets": targets,
			"reflects": e.action == SourceShieldEffect.Action.REFLECT})
	for src in g.players[pid].battlefield:
		for index in src.cur_activated_abilities.size():
			var a: ActivatedAbility = src.cur_activated_abilities[index]
			if a.effects.size() != 1:
				continue
			var e: EffectBase = a.effects[0]
			if e is SourceShieldEffect:
				if not shield_covers(g, e, src, victim, pid):
					continue
			elif e is PreventDamageShieldEffect:
				# The Circle's modern form: "... to you" (Righteous Aura,
				# Prismatic Circle, the Circles of Protection).
				if not victim.is_player or victim.player_id != pid \
						or g.rules.damage_prevention_window:
					continue
			else:
				continue
			if not shield_may_name(g, e, src, threat, pid):
				continue
			if not pilot._ability_available(g, src, index, true):
				continue
			if not victim.is_player and a.sacrifice_filter.is_valid() \
					and victim.instance_id == src.id:
				continue
			var surcharge := g.ability_surcharge(pid, src)
			var own: Array = sources if not a.tap_cost \
				else sources.filter(func(row: Array) -> bool: return row[0] != src)
			if not (pilot._cost_is_free(a.cost) and surcharge == 0) \
					and pilot._plan_taps_from(own, a.cost, surcharge,
						g.ability_mana_usage_keys(src)).is_empty():
				continue
			var price: float = float(a.cost.mana_value()) * 0.5 + float(pilot._sacrifice_price(g, src, a)) \
				+ float(a.life_cost) * pilot._life_price(g.players[pid].life)
			var aimed: Array = []
			if e is SourceShieldEffect and e.target_spec != null:
				aimed = [victim]
			out.append({"price": price, "kind": &"ability", "inst": src, "index": index,
				"mode": 0, "targets": aimed,
				"reflects": e is SourceShieldEffect and e.action == SourceShieldEffect.Action.REFLECT})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["price"]) < float(b["price"]))
	return out


## Raise a shield against the damage about to be dealt: a damage spell or
## ability of theirs on top of the stack aimed at us or at a creature of
## ours it would kill ([method MtgGame.predict_damage], our seat as the
## viewer), or — their blocks known — the attacker whose damage kills us
## or the creature of ours that dies to it. The shield's source choice is
## made on resolution by the engine's ranked chooser, which names the
## threat ([method MtgGame.choose_damage_source]).
static func shield_response(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	var life := g.players[pid].life
	var foe: int = g.opponent_of(pid)
	var threats: Array = []   # [victim TargetRef, worth, threat source, damage]
	if not g.stack.is_empty():
		var top: StackItem = g.stack.back()
		if top.controller != pid and top.card != null:
			var intent := EffectIntent.read(top.effects, top.card.data.card_name)
			var dmg := intent.damage_at(top.x_value)
			if dmg > 0:
				for t in top.targets:
					if t == null or t.is_damage or t.is_ability:
						continue
					if t.is_player:
						if t.player_id != pid:
							continue
						var landed := int(g.predict_damage(top.card, t, dmg, false, -1, pid)["dealt"])
						if landed >= life:
							threats.append([t, pilot.LETHAL_WORTH, top.card, landed])
						elif landed > 0:
							threats.append([t, float(landed) * pilot._life_price(life), top.card, landed])
					else:
						var victim := g.find_instance(t.instance_id)
						if victim == null or victim.controller_id != pid or not victim.is_creature():
							continue
						if bool(g.predict_damage(top.card, t, dmg, false, -1, pid)["dies"]):
							threats.append([t, pilot._own_value(g, victim), top.card, dmg])
	elif g.current_step() == Mtg.Step.DECLARE_BLOCKERS and not g.awaiting_blockers \
			and g.active_player != pid and not g.combat.attackers.is_empty() \
			and not g.combat_damage_prevented:
		# Blocks are known: each unblocked attacker's damage at us (the one
		# a shield names — the biggest, as the engine's chooser ranks), and
		# each blocker of ours that dies.
		var incoming: int = pilot._incoming_damage(g)
		var biggest: CardInstance = null
		for id in g.combat.attackers:
			var a := g.find_instance(id)
			if a == null or not g.is_present(a) or g.combat.was_blocked(g.combat.band_of(id)):
				continue
			if biggest == null or a.cur_power > biggest.cur_power:
				biggest = a
		if biggest != null and biggest.cur_power > 0:
			var hit := maxi(biggest.cur_power, 0)
			var worth: float = float(hit) * pilot._life_price(life)
			if incoming >= life and incoming - hit < life:
				worth = pilot.LETHAL_WORTH
			threats.append([TargetRef.player(pid), worth, biggest, hit])
		for inst in g.players[pid].battlefield:
			if inst.is_creature() and g.combat.blocks.has(inst.id) and pilot._dies_in_combat(g, inst):
				var killer: CardInstance = null
				for aid in g.combat.attackers_blocked_by(inst.id):
					killer = g.find_instance(aid)
				threats.append([TargetRef.card(inst), pilot._own_value(g, inst), killer, 0])
	threats.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	for row in threats:
		var victim: TargetRef = row[0]
		var threat: CardInstance = row[2]
		if already_shielded(g, pid, threat):
			continue   # one shield per source: a second would watch nothing
		var tools := shield_tools(g, pilot, victim, threat)
		if tools.is_empty():
			continue
		var tool: Dictionary = tools[0]
		var worth: float = row[1]
		# A REFLECTED hit lands on its source's controller: their face.
		if bool(tool.get("reflects", false)) and threat != null and threat.controller_id == foe \
				and int(row[3]) > 0:
			if int(row[3]) >= g.players[foe].life:
				worth = pilot.LETHAL_WORTH
			else:
				worth += pilot._face_damage_value(g, int(row[3]), foe)
		if worth < float(tool["price"]) + 0.5:
			continue
		var label: String = "us" if victim.is_player else g.find_instance(victim.instance_id).data.card_name
		var done := use_tool(g, pilot, tool, "shields %s" % label)
		if done != "":
			return done
	return ""


## Is a shield of [param pid]'s already waiting for [param threat] — a
## damage effect on the table naming it as its source (the audit's
## Shadowbane AND Reflect Damage on one Canopy Dragon), or a Circle's
## chosen-source shield on the seat?
static func already_shielded(g: MtgGame, pid: int, threat: CardInstance) -> bool:
	if threat == null:
		return false
	for e in g.damage_effects:
		if int(e.get("controller", -1)) == pid and int(e.get("source_id", -1)) == threat.id:
			return true
	for row in g.players[pid].prevention_shield_filters:
		if int(row.get("chosen_source", -1)) == threat.id:
			return true
	return false


## THE RANSOM (Sabertooth Cobra's "unless they pay {2} before that step"
## — [method MtgGame.settleable_delayed_triggers]): paid at their end step
## with mana the untap step would otherwise waste, after the held
## instants have had theirs. Asked by [method AiPlayer._end_of_their_turn].
static func pay_ransom(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics or g.active_player == pilot.pid \
			or g.current_step() != Mtg.Step.END or not g.stack.is_empty():
		return ""
	for entry in g.settleable_delayed_triggers(pilot.pid):
		var cost: ManaCost = entry.get("settle_cost")
		if cost == null or not g.can_afford_cost(pilot.pid, cost):
			continue
		if g.settle_delayed_trigger(pilot.pid, int(entry["id"])) == "":
			return "pays %s: %s" % [str(cost), String(entry.get("desc", "a ransom"))]
	return ""


## TORRENT OF LAVA'S GRANTED SHIELD: "{T}: Prevent the next 1 damage that
## would be dealt to this creature by Torrent of Lava this turn" — tapped
## when the sweep on the stack would kill the creature by exactly the one
## point the shield takes off. Read off the ability's printed line.
static func torrent_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility) -> Variant:
	if not a.tap_cost or not a.text.to_lower().contains("prevent the next 1 damage that would be dealt to this creature by"):
		return null
	for item in g.stack:
		if item.card == null or item.effects.is_empty():
			continue
		var e: EffectBase = item.effects[0]
		if not (e is DamageAllEffect):
			continue
		var n: int = item.x_value if e.use_x else e.amount
		if pilot._sweep_kills(e, s, n) and not pilot._sweep_kills(e, s, n - 1):
			return {"value": pilot._own_value(g, s) + 1.0, "targets": []}
	return {}


# ======================================================= the turn skips --

## "You skip your next turn" / "you skip your next untap step" on an
## ability's printed line (Chronatog, Avizoa; engine package E8). A turn
## is a price nothing else in the planner can weigh, so the AI keeps these
## OPAQUE (card batch B10 left the second effect unknown on purpose, and
## the breath readers skip it) — except where the turn no longer matters:
## the +N/+N is the damage that ends the game now. Asked as an expansion
## arm so the answer is always explicit: {} unless lethal.
static func turn_skip_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Variant:
	var line := a.text.to_lower()
	if not line.contains("skip your next turn") and not line.contains("skip your next untap step"):
		return null
	var bonus := 0
	for e in a.effects:
		if e is PumpEffect and e.self_mode:
			bonus += e.power
	if bonus <= 0 or window != "RESPONSE" or g.active_player != pilot.pid \
			or g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers \
			or not g.combat.attackers.has(s.id) or g.combat.was_blocked(g.combat.band_of(s.id)) \
			or g.combat_damage_prevented:
		return {}
	var foe: int = g.opponent_of(pilot.pid)
	var through := 0
	for id in g.combat.attackers:
		var attacker := g.find_instance(id)
		if attacker != null and g.is_present(attacker) \
				and not g.combat.was_blocked(g.combat.band_of(id)):
			through += maxi(attacker.cur_power, 0)
	if through < g.players[foe].life and through + bonus >= g.players[foe].life:
		return {"value": pilot.LETHAL_WORTH, "targets": []}
	return {}


# =================================================== instant-only mana --

## Is [param ability] mana that costs the whole HAND and may be tapped only
## at instant speed (Lion's Eye Diamond: "Discard your hand, Sacrifice
## this artifact: Add three mana of any one color. Activate only as an
## instant")? The planner never auto-taps it (engine package E6); the
## mulligan never counts it ([method AiMulligan.is_free_source]).
static func hand_cost_mana(ability: ManaAbility) -> bool:
	if not ability.instant_only and ability.object_costs.is_empty():
		return false
	for group in ability.object_costs:
		if String(group.get("operation", "")) == "discard_hand":
			return true
	return ability.instant_only


## THE DIAMOND, cracked only for value: our hand is EMPTY (the discard
## costs nothing), and an activated ability of ours that the mana on the
## table cannot pay for becomes payable with its three mana of one colour
## and clears its own bar ([method AiPlayer._ability_option]). The mana
## floats; the next action spends it. Anything else — a hand with a card
## in it, a payment the ability does not need — leaves the Diamond where it
## is: no crash, no waste.
static func lion_eye_action(g: MtgGame, pilot, moment: int) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	var pid: int = pilot.pid
	if not g.players[pid].hand.is_empty():
		return ""
	var sources: Array = pilot._mana_sources(g)
	for diamond in g.players[pid].battlefield:
		for row in diamond.cur_mana_abilities.size():
			var mana: ManaAbility = diamond.cur_mana_abilities[row]
			if not hand_cost_mana(mana) or mana.produces.is_empty():
				continue
			var colour := int(mana.produces[0][0])
			var amount := int(mana.produces[0][1])
			var with_it: Array = sources.duplicate()
			for unit in amount:
				with_it.append([null, LAND_UNIT_BASE + unit, colour, 1, false, "", 0, 0])
			for inst in g.players[pid].battlefield:
				if inst == diamond:
					continue
				for index in inst.cur_activated_abilities.size():
					var a: ActivatedAbility = inst.cur_activated_abilities[index]
					if a.cost == null or pilot._cost_is_free(a.cost) or a.cost.has_x:
						continue
					if not pilot._ability_available(g, inst, index, true):
						continue
					var surcharge := g.ability_surcharge(pid, inst)
					if not pilot._plan_taps_from(sources, a.cost, surcharge).is_empty():
						continue   # payable already: the Diamond buys it nothing
					if pilot._plan_taps_from(with_it, a.cost, surcharge).is_empty():
						continue
					var option: Dictionary = pilot._ability_option(g, inst, index, moment)
					if option.is_empty():
						continue
					var bar := 3.0 if moment == 0 else 0.5
					if float(option["value"]) < float(option.get("bar", bar)):
						continue
					if g.tap_for_mana(pid, diamond, row) == "":
						return "cracks %s for %s" % [diamond.data.card_name, inst.data.card_name]
	return ""


# ========================================================= bans and locks --

## What one ban-callable answer weighs: 1.0 when [param ability] of
## [param p] (controlled by [param seat]) is refused whoever's turn it is,
## 0.5 when only on the other seat's turn (City of Solitude's "only during
## their own turns"), 0.0 when never.
static func _ban_weight(g: MtgGame, ban: Callable, src: CardInstance, seat: int,
		p: CardInstance, ability: Variant, is_mana: bool) -> float:
	var now := bool(ban.call(g, src, seat, p, ability, is_mana))
	var flip := bool(ban.call(g, src, g.opponent_of(seat), p, ability, is_mana))
	if now and flip:
		return 1.0
	return 0.5 if now != flip else 0.0


## THE LOCK'S SWING for a permanent in hand that radiates an ACTIVATION
## BAN (Null Rod, Cursed Totem, City of Solitude, Katabatic Winds —
## engine package E4's [member CardData.activation_ban]): every activated
## and mana ability on the table it would stop, theirs for us and ours
## against us, a mana ability of a nonland permanent (a Mox, a Llanowar
## Elves) weighing more; and, for a lock that also bans PLAYING on the
## other seat's turn, each instant in our own hand it strands. Public
## board and own hand only; their hand is not guessed at.
static func ban_swing(g: MtgGame, pilot, inst: CardInstance) -> float:
	var ban: Callable = inst.data.activation_ban
	if not ban.is_valid():
		return 0.0
	var pid: int = pilot.pid
	var swing := 0.0
	for p in g.all_battlefield():
		var seat := p.controller_id
		var sign := 1.0 if seat != pid else -1.0
		for a in p.cur_activated_abilities:
			swing += sign * _ban_weight(g, ban, inst, seat, p, a, false)
		for m in p.cur_mana_abilities:
			var weight := 0.5 if p.is_land() else 1.5
			swing += sign * weight * _ban_weight(g, ban, inst, seat, p, m, true)
	if inst.data.play_ban.is_valid():
		for card in g.players[pid].hand:
			if card != inst and card.is_type(Mtg.CardType.INSTANT):
				swing -= 1.0
	return swing


## PEACE TALKS ("this turn and next turn, creatures can't attack, and
## players and permanents can't be the targets of spells or activated
## abilities"): two turns of no combat, which helps the side being raced.
## Cast after our own attack (our second main phase — or the first when
## we have nothing that could attack) when their clock is lethal or
## clearly faster than ours ([method AiPlayer._race_reach], phased
## creatures included). Read off the effect's printed line.
static func truce_value(g: MtgGame, pilot) -> float:
	var pid: int = pilot.pid
	var foe: int = g.opponent_of(pid)
	if g.active_player != pid:
		return 0.0
	if g.current_step() == Mtg.Step.MAIN1 \
			and not pilot._attack_candidates(g, foe).is_empty():
		return 0.0   # attack first; the truce is a second-main card
	var theirs: int = pilot._race_reach(g, foe, pid)
	var ours: int = pilot._race_reach(g, pid, foe)
	var life := g.players[pid].life
	if theirs >= life:
		return 50.0
	if theirs - ours >= 3:
		return float(theirs - ours) * pilot._life_price(life)
	return 0.0


## The main-phase arm for the locks above, asked from [method spell_choice].
static func lock_choice(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	if inst.data.activation_ban.is_valid():
		var swing := ban_swing(g, pilot, inst)
		return {} if swing < 1.5 else {"x": 0, "targets": [], "value": swing + 1.0}
	if inst.data.spell_effects.size() == 1:
		var e: EffectBase = inst.data.spell_effects[0]
		if e.target_spec == null and not (e is PumpEffect) and e.ai_role == &"" \
				and e.describe().to_lower().contains("creatures can't attack"):
			var value := truce_value(g, pilot)
			return {} if value <= 0.0 else {"x": 0, "targets": [], "value": value}
	return null


## THE FLOATING BANS at their upkeep (Solfatara's "target player can't
## play lands this turn", Abeyance's "can't cast instant or sorcery spells
## or activate abilities that aren't mana abilities" — both cantrips): cast
## at the opponent as their turn begins, when the mana is not held for an
## answer of ours. Read off the effect's printed line.
static func upkeep_ban(g: MtgGame, pilot) -> String:
	if g.active_player == pilot.pid or g.current_step() != Mtg.Step.UPKEEP \
			or not g.stack.is_empty():
		return ""
	var pid: int = pilot.pid
	var foe: int = g.opponent_of(pid)
	var sources: Array = pilot._mana_sources(g)
	var reserve: Dictionary = pilot._held_reserve(g)
	for inst in g.players[pid].hand:
		if not inst.is_type(Mtg.CardType.INSTANT) or inst.data.spell_effects.is_empty() \
				or pilot._refused.has(str(inst.id)):
			continue
		var e: EffectBase = inst.data.spell_effects[0]
		if e.target_spec == null or e.target_spec.kind != TargetSpec.Kind.PLAYER \
				or e.ai_role != &"":
			continue
		var line := e.describe().to_lower()
		if not line.contains("can't play lands") and not line.contains("can't cast instant"):
			continue
		var ref := TargetRef.player(foe)
		if g.cast_refusal(pid, inst, [ref]) != "":
			continue
		var surcharge := g.spell_surcharge(pid, inst.data)
		var cost := inst.data.cost
		if not reserve.is_empty() and int(reserve.get("for", -1)) != inst.id:
			cost = pilot._combined_cost(cost, reserve["cost"])
		if pilot._plan_taps_from(sources, cost, surcharge).is_empty():
			continue
		var cast: String = pilot._cast_response(g, inst, [ref], 0,
			"cast %s at their upkeep" % inst.data.card_name)
		if cast != "":
			return cast
	return ""


# ======================================================= the choice roles --

## THE CHOICE CARDS of card batch B1, read by their declared roles
## (cards/sets/{mir,wth}/_choices.gd): null when [param inst] carries none.
##  * `library_build` (Doomsday — five cards kept, the rest of library and
##    graveyard exiled, half the life lost): a combo piece this pilot has no
##    combo for. Never cast.
##  * `land_balance` (Natural Balance — six or more lands are cut to five,
##    four or fewer fetch up to five): cast when it gains us more lands
##    than it gains them, counted off the two battlefields.
##  * `tariff` (each player sacrifices its highest-mana-value creature
##    unless it pays that much): cast when their payment is out of reach of
##    their open mana and ours is not a worse loss.
##  * `life_bid_steal` (Illicit Auction): cast at a creature of theirs only
##    when our bidding limit beats theirs — the card's own public hint bids
##    up to the body's size while six life stay — priced at the life the
##    winning bid costs.
##
## And the bug pass's three (2026-10-04, cards/sets/{mir,vis}):
##  * `color_sweep_life_toll` (Reign of Terror — destroy all green or all
##    white creatures, 2 life lost per death): the colour the card's own
##    `pick` hint names is priced as the sweep it is, less the life it costs
##    at the reaper's rate; never cast when those deaths are our last life.
##  * `cats_per_untapped_forest` (Waiting in the Weeds — each player a 1/1
##    for each UNTAPPED Forest as it resolves): our Forests counted after
##    the plan that pays for it, theirs as they stand; cast only for more
##    cats than theirs.
##  * `impulse_exile` (Three Wishes — three cards playable until our next
##    turn, then gone): cast in our own main phase with a land drop to take
##    from them or two mana left over after paying, never held for their
##    end step ([method AiPlayer._is_held_instant]).
static func role_choice(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	var role: StringName = &""
	var tagged: EffectBase = null
	for e in inst.data.spell_effects:
		if e.ai_role in [&"library_build", &"land_balance", &"tariff", &"life_bid_steal",
				&"color_sweep_life_toll", &"cats_per_untapped_forest", &"impulse_exile"]:
			role = e.ai_role
			tagged = e
	if role == &"":
		return null
	var pid: int = pilot.pid
	var foe: int = g.opponent_of(pid)
	match role:
		&"color_sweep_life_toll":
			var filters: Array = tagged.ai_parameters.get("filters", [])
			var pick: Callable = tagged.ai_parameters.get("pick", Callable())
			if filters.is_empty() or not pick.is_valid():
				return {}
			var chosen := clampi(int(pick.call(g, pid)), 0, filters.size() - 1)
			var sweep := DestroyAllEffect.new("", filters[chosen], false)
			var deaths := 0
			for c in g.all_battlefield():
				if c.is_creature() and pilot._sweep_kills(sweep, c, 0):
					deaths += 1
			var toll := deaths * int(tagged.ai_parameters.get("life_per_death", 0))
			var life := g.players[pid].life
			if toll >= life:
				return {}
			var swing: float = pilot._sweep_value(g, sweep, 0, inst) \
				- float(toll) * pilot._life_price(life - toll)
			return {} if swing < pilot.SWEEP_BAR else {"x": 0, "targets": [], "value": swing}
		&"cats_per_untapped_forest":
			var spent := _plan_spends(g, pilot, inst)
			var ours := 0
			var theirs := 0
			for land in g.all_battlefield():
				if not land.is_land() or land.tapped or not land.has_subtype("forest") \
						or not g.is_present(land):
					continue
				if land.controller_id != pid:
					theirs += 1
				elif not spent.has(land.id):
					ours += 1
			if ours <= theirs or not (tagged is CreateTokenEffect):
				return {}
			var cat: float = pilot._token_value({"power": tagged.token.power,
				"toughness": tagged.token.toughness})
			return {"x": 0, "targets": [], "value": float(ours - theirs) * cat}
		&"impulse_exile":
			if g.active_player != pid or not Mtg.is_main_step(g.current_step()):
				return {}
			var cards := mini(3, g.players[pid].library.size())
			if cards <= 0:
				return {}
			var spent := _plan_spends(g, pilot, inst)
			var left := 0
			for row in pilot._mana_sources(g):
				if row[0] == null or not spent.has(row[0].id):
					left += 1
			if not g.land_drop_available(pid) and left < 2:
				return {}
			return {"x": 0, "targets": [], "value": float(cards) + pilot._draw_need(g.players[pid].hand.size())}
		&"library_build":
			return {}
		&"land_balance":
			var ours := 0
			var theirs := 0
			for p in g.players[pid].battlefield:
				if p.is_land(): ours += 1
			for p in g.players[foe].battlefield:
				if p.is_land(): theirs += 1
			var swing := float(maxi(theirs - 5, 0) - maxi(ours - 5, 0) \
				+ maxi(5 - ours, 0) - maxi(5 - theirs, 0))
			return {} if swing < 2.0 else {"x": 0, "targets": [], "value": swing * 1.5}
		&"tariff":
			var value := 0.0
			var their_best := _highest_mv_creature(g, foe)
			if their_best != null and pilot._their_open_mana(g, foe) < their_best.data.cost.mana_value():
				value += pilot._victim_value(g, their_best)
			var our_best := _highest_mv_creature(g, pid)
			if our_best != null:
				var after: int = pilot._mana_sources(g).size() - inst.data.cost.mana_value()
				if after < our_best.data.cost.mana_value():
					value -= pilot._own_value(g, our_best)
			return {} if value < 2.0 else {"x": 0, "targets": [], "value": value}
		&"life_bid_steal":
			var best := {}
			var spec: TargetSpec = inst.data.spell_effects[0].target_spec
			for c in g.players[foe].battlefield:
				if not c.is_creature() or not spec.is_legal(g, TargetRef.card(c), inst):
					continue
				var worth := maxi(c.cur_power, 0) + maxi(c.cur_toughness, 0)
				var our_limit := mini(worth, g.players[pid].life - 6)
				var their_limit := mini(worth, g.players[foe].life - 6)
				if our_limit <= maxi(their_limit, 0):
					continue
				var cost: float = float(maxi(their_limit, 0) + 1) * pilot._life_price(g.players[pid].life)
				var value: float = pilot._victim_value(g, c) * 2.0 - cost
				if value >= 3.0 and (best.is_empty() or value > float(best["value"])):
					best = {"x": 0, "targets": [TargetRef.card(c)], "value": value}
			return best
	return null


## The permanents the plan that pays for [param inst] would tap, as
## `{id: true}` — the same plan [method AiPlayer._try_cast_best] checks.
static func _plan_spends(g: MtgGame, pilot, inst: CardInstance) -> Dictionary:
	var out := {}
	var plan: Array = pilot._plan_taps_from(pilot._mana_sources(g), inst.data.cost,
		g.spell_surcharge(pilot.pid, inst.data), g.mana_usage_keys(inst.data, inst))
	for step in plan:
		if step[0] != null:
			out[step[0].id] = true
	return out


static func _highest_mv_creature(g: MtgGame, seat: int) -> CardInstance:
	var best: CardInstance = null
	for c in g.players[seat].battlefield:
		if c.is_creature() and (best == null or c.data.cost.mana_value() > best.data.cost.mana_value()):
			best = c
	return best


## Could [param inst] deal damage at all this turn — the question a
## "source of your choice" answer has to ask before it names one? A spell
## on the stack, a creature, or a permanent with an ability of its own
## (a Rod of Ruin, a Pestilence); never a plain land or a static-only
## permanent, which the engine's chooser ranks only to have SOME answer.
static func could_deal_damage(g: MtgGame, inst: CardInstance) -> bool:
	if inst == null:
		return false
	if inst.zone == Mtg.Zone.STACK or inst.is_creature():
		return true
	# A packet waiting in the 1997 damage-prevention window: its source
	# (a resolved Lightning Bolt, in the graveyard by now) is the one
	# dealing it.
	for packet in g.damage_pending:
		if packet.source == inst:
			return true
	return not inst.cur_activated_abilities.is_empty() \
		or not inst.cur_triggered_abilities.is_empty()


## The answer to a "Select a source" question (the shields' choice — the
## candidates come ranked by the engine): the first that could deal damage
## ([method could_deal_damage]), else the engine's first.
static func pick_damage_source(g: MtgGame, candidates: Array[CardInstance]) -> CardInstance:
	for c in candidates:
		if could_deal_damage(g, c):
			return c
	return null if candidates.is_empty() else candidates[0]



# ============================================ the Mirage bug pass (AI) --
#
# The 2026-10-04 bug pass's readings (docs/pack-8-mirage-block.md, "AI
# review"): spells and creatures the pilot cast to its own loss. Every one
# is read off a typed effect, a declared role or a printed line, and every
# one answers its null with [member AiProfile.forecasts_tactics] off.

## The printed arrival of a body whose only toughness is the counters it
## counts ("This creature enters with a +1/+1 counter on it for each
## creature card in your graveyard"), read off the oracle the way [method
## aura_pump] reads a pump.
const COUNTS_GRAVE_CREATURES := "enters with a +1/+1 counter on it for each creature card in your graveyard"

## The printed keep-price on an arrival trigger ("When this creature
## enters, sacrifice it unless you sacrifice any number of creatures with
## total power 12 or greater").
const KEEP_BY_POWER := "sacrifice it unless you sacrifice any number of creatures with total power "

## The most bodies the keep-price's own hint gives up (the card answers
## "keep it?" with yes only when two creatures or fewer reach the power).
const KEEP_BODIES := 2


## Would [param inst], a creature card in hand, be lost the moment it
## arrives? A 2/0 whose counters count nothing dies to the state-based
## check (CR 704.5f) — ours is a graveyard both seats see — and a body
## whose arrival trigger sacrifices it unless creatures with total power N
## are given is sacrificed when our other creatures cannot reach N within
## the bodies the card's own hint will give ([constant KEEP_BODIES]).
static func dies_on_arrival(g: MtgGame, pilot, inst: CardInstance) -> bool:
	if not pilot.profile.forecasts_tactics or not inst.data.is_creature():
		return false
	var pid: int = pilot.pid
	if inst.data.toughness <= 0 \
			and inst.data.oracle_text.to_lower().contains(COUNTS_GRAVE_CREATURES):
		var counted := 0
		for card in g.players[pid].graveyard:
			if card.data.is_creature():
				counted += 1
		if inst.data.toughness + counted <= 0:
			return true
	for t in inst.data.triggered_abilities:
		if t.event_type != Mtg.EventType.ENTERS_BATTLEFIELD:
			continue
		var line := t.text.to_lower()
		var at := line.find(KEEP_BY_POWER)
		if at < 0:
			continue
		var words := line.substr(at + KEEP_BY_POWER.length()).split(" ", false)
		if words.is_empty() or not words[0].is_valid_int():
			continue
		var need := int(words[0])
		var powers: Array[int] = []
		for body in g.players[pid].battlefield:
			if body.is_creature() and g.is_present(body) and body.cur_power > 0:
				powers.append(body.cur_power)
		powers.sort()
		powers.reverse()
		var reached := 0
		var bodies := 0
		for power in powers:
			if reached >= need:
				break
			reached += power
			bodies += 1
		if reached < need or bodies > KEEP_BODIES:
			return true
	return false


## The token line of a spell whose token is gone at the next end step
## ("Create a 5/5 blue Wall creature token with defender. Sacrifice it at
## the beginning of the next end step." — Tidal Wave).
const DOOMED_TOKEN := "sacrifice it at the beginning of the next end step"


## The token [param data] makes when that token is sacrificed at the next
## end step, or null. Made in our own turn it is summoning-sick until it is
## gone (and a defender never attacks at all): its moment is their attack
## ([method token_ambush]).
static func doomed_token(data: CardData) -> CardData:
	if not data.oracle_text.to_lower().contains(DOOMED_TOKEN):
		return null
	for e in data.spell_effects:
		if e is CreateTokenEffect:
			return e.token
	return null


## THE DOOMED WALL AS AN AMBUSH: their attackers are declared, our blocks
## are not; an instant whose token lives only until the end step is cast
## now to block. Worth it when the token kills an attacker and lives, keeps
## back damage worth the card, or turns a lethal attack into a survived one.
static func token_ambush(g: MtgGame, pilot) -> String:
	if g.active_player == pilot.pid or g.current_step() != Mtg.Step.DECLARE_ATTACKERS \
			or g.combat.attackers.is_empty() or not g.stack.is_empty():
		return ""
	var pid: int = pilot.pid
	var life := g.players[pid].life
	var sources: Array = pilot._mana_sources(g)
	var attackers: Array[CardInstance] = pilot._declared_attackers(g)
	var before: int = pilot._damage_through_blocks(g, attackers, pilot._untapped_creatures(g, pid), pid)
	var best: CardInstance = null
	var best_value := 0.0
	for inst in g.players[pid].hand:
		var token := doomed_token(inst.data)
		if token == null or not g.casts_at_instant_speed(pid, inst) \
				or pilot._refused.has(str(inst.id)) or pilot._cast_gate(g, inst) != "":
			continue
		var surcharge := g.spell_surcharge(pid, inst.data)
		if not (pilot._cost_is_free(inst.data.cost) and surcharge == 0) \
				and pilot._plan_taps_from(sources, inst.data.cost, surcharge,
					g.mana_usage_keys(inst.data, inst)).is_empty():
			continue
		var value := 0.0
		for attacker in attackers:
			var read := _ambush_read(token, attacker)
			if not bool(read["blocks"]):
				continue
			if bool(read["kills"]) and bool(read["lives"]):
				value = maxf(value, pilot._victim_value(g, attacker) + 1.0)
			var kept := maxi(attacker.cur_power, 0)
			if attacker.has_keyword(Mtg.Keyword.TRAMPLE):
				kept = mini(kept, token.toughness)
			value = maxf(value, float(kept) * pilot._life_price(life))
			if before >= life and before - kept < life:
				value = pilot.LETHAL_WORTH
		if value < maxf(3.0, Evaluator.card_value(inst.data)) or value <= best_value:
			continue
		best = inst
		best_value = value
	if best == null:
		return ""
	return pilot._cast_response(g, best, [], 0, "cast %s as a surprise blocker" % best.data.card_name)


## Torrent of Lava's grant, read off the spell's stack static: "each
## creature has \"{T}: Prevent the next 1 damage that would be dealt to this
## creature by Torrent of Lava this turn.\"" (CR 611.3). The same line
## [method torrent_option] answers from the creature's side.
const TAP_SHIELD := "prevent the next 1 damage that would be dealt to this creature by"


## The damage each creature can tap away from [param source], a sweep
## whose stack static grants the {T} shield, or 0.
static func granted_tap_shield(source: CardInstance) -> int:
	if source == null:
		return 0
	for s in source.data.stack_static_abilities:
		var line := s.text.to_lower()
		if line.contains("{t}:") and line.contains(TAP_SHIELD):
			return 1
	return 0


## Can [param inst] pay a {T} cost right now — untapped, and not under
## summoning sickness unless it has haste (CR 302.6)?
static func can_tap_now(inst: CardInstance) -> bool:
	return inst.is_creature() and not inst.tapped \
		and not (inst.summoning_sick and not inst.has_keyword(Mtg.Keyword.HASTE))
