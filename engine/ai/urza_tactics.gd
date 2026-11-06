extends RefCounted
## Pack 10 (the Urza block): the fair AI's readings of the block's board,
## combat and activation shapes, in the shape of the other expansion
## modules — static functions that return null when their shape is not
## involved or their gate is off (the null arm: the pilot plays exactly as
## it did before Pack 10), `{}` for "no, not now", or `{value, targets}`;
## the action arms answer the action line or "".
##
## Information: the public board, the stack, both hand SIZES and the
## pilot's own hand and graveyard only (docs/fair-play.md). Shape, not
## name: every arm reads a typed effect, a cost's own fields, a counter
## the permanent carries in public or the ability's printed line.
##
## THE GATE is the profile's existing [member AiProfile.forecasts_tactics]
## (docs/ai-difficulty.md §1), no new scale. Reached through the Mirage
## module (engine/ai/mirage_tactics.gd): its activation arm ([method
## option]), its response arm ([method respond]) and its two combat
## repairs ([method price_attackers], [method price_blocks]) ask this
## module first.
##
## THE SHAPES:
##  * A GIFT OF ITSELF ("target opponent gains control of this creature",
##    Witch Engine; Goblin Festival's lost flip): never paid for, except
##    for the damage that ends the game ([method gift_option]).
##  * COUNTERS CASHED IN (the verse, page and fuse counters: "where X is
##    the number of <kind> counters on this"): never at X = 0, and
##    otherwise only when X covers what the board shows, or the
##    permanent is about to go anyway ([method counter_cash_option]);
##    Serra's Hymn's prevention only on our own side, against damage the
##    stack or a blocked combat shows coming ([method hymn_cash]).
##  * AN AURA SOLD FOR A CARD (Capashen Standard, Illuminated Wings): only
##    when its host is about to leave, or is theirs ([method aura_cash_option]).
##  * THE LIFE PAID AS IT ENTERED (Phyrexian Processor's X/X) and HALF THE
##    LIFE paid for a body (Lurking Evil): read through the life the
##    engine would really take ([method MtgGame.ability_life_cost]).
##  * A CARD FROM THE HAND ONTO THE BATTLEFIELD (Elvish Piper — any
##    creature, Quicksilver Amulet, Copper Gnomes), and the ONE-TURN BODY
##    (Sneak Attack, Apprentice Necromancer: sacrificed at the next end
##    step) only for an attack that ends the game or takes half of it.
##  * UNTAPS: a permanent that does not untap by itself (Grim Monolith,
##    Phyrexian Colossus) untapped with their end step's spare mana; a
##    creature that untaps itself stands guard after it attacked; Voltaic
##    Key on such an artifact, or on one whose tap takes an extra turn.
##  * REPEATED PINGS (Masticore): a creature the pings can finish with the
##    mana on the table, never a first ping the mana cannot follow up.
##  * A SHRINK THAT KILLS (the Phyrexian -N/-N sacrifices).
##  * THE OPAL DODGE (Opal Acrolith's "{0}: becomes an enchantment"): in
##    answer to removal or a lost combat, never otherwise ([method respond]).
##  * COMBAT: a creature that changes sides when it blocks or is blocked
##    (Goblin Cadets) and one that costs permanents for each point it is
##    dealt (Phyrexian Negator) stay out of fights the board shows they
##    lose ([method price_attackers], [method price_blocks]).

const TEMPEST_TACTICS := preload("res://engine/ai/tempest_tactics.gd")
const HOMELANDS_TACTICS := preload("res://engine/ai/homelands_tactics.gd")

## The two printed ways an ability states that its X is the source's own
## counters ("where X is the number of verse counters on this
## enchantment"; Powder Keg's "equal to the number of fuse counters").
const COUNTED_MARKS: Array[String] = ["where x is the number of ", "equal to the number of "]
## Up-to-X targets: cashed once X covers this many of them even when the
## board shows more (three creatures, three lands).
const COVER_ENOUGH := 3
## A land destroyed is a turn of the opponent's mana, worth more than its
## printed card.
const LAND_WORTH := 2.5
## A card from Discordant Dirge, priced like a card off a hand.
const DIRGE_CARD := 2.5
## Powder Keg's net (theirs less ours) worth blowing.
const KEG_NET := 3.0
## The life a self-paid animation must leave above the opponent's visible
## power (their next swing), and its absolute floor.
const LIFE_MARGIN := 2
const LIFE_FLOOR := 5
## How many bodies Damping Engine's ignore prices under the search journal
## ([method damping_action]) — each is a sacrifice and a read of the hand.
const IGNORE_TRIES := 3


# ======================================================= the activations --

## The activation arm, asked first by [method MirageTactics.option] (which
## every activation asks through [method AiPlayer._ability_option]).
static func option(g: MtgGame, pilot, s: CardInstance, index: int,
		window: String) -> Variant:
	if not pilot.profile.forecasts_tactics:
		return null
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	if a.effects.is_empty():
		return null
	if gives_itself_away(a) and not a.effects.any(func(x: EffectBase) -> bool: return x.ai_role != &""):
		return gift_option(g, pilot, s, a, window)   # a declared role (Jinxed Idol's donation) is its reader's
	if counted_kind(a) != "":
		var cashed: Variant = counter_cash_option(g, pilot, s, a, window)
		if cashed != null:
			return cashed
	if s.data.is_aura() and a.sacrifice_cost and a.effects[0] is DrawEffect:
		return aura_cash_option(g, pilot, s, a, window)
	if becomes_enchantment(a):
		return {}   # the dodge is the response arm's ([method opal_dodge])
	if animates_for_life(s, a):
		return lurking_option(g, pilot, s, a, window)
	var e: EffectBase = a.effects[0]
	if e is CreateTokenEffect and _line(e).contains("life paid"):
		return processor_option(g, pilot, s, window)
	var kind := from_hand_kind(a)
	if kind != 0:
		return from_hand_option(g, pilot, s, a, kind, window)
	if one_turn_raise(a):
		return one_turn_raise_option(g, pilot, s, a, window)
	if untaps_itself(a):
		return untap_self_option(g, pilot, s, a, window)
	if e is UntapEffect and e.target_spec != null and e.target_max == 1 \
			and a.effects.size() == 1:
		return untap_artifact_option(g, pilot, s, a, window)
	if TEMPEST_TACTICS.shrinks_blocker(e) and a.effects.size() == 1:
		return shrink_kill_option(g, pilot, s, a, window)
	if e is DamageEffect and a.text.to_lower().contains("target attacking or blocking creature"):
		return combat_shot_option(g, pilot, s, a, window)
	if repeat_ping(a):
		return repeat_ping_option(g, pilot, s, a, window)
	var toll := each_opponent_damage(a)
	if toll > 0 and e.target_spec == null:
		return toll_option(g, pilot, toll, window)
	if bargain(a):
		return bargain_option(g, pilot, s, a)
	return null


# ------------------------------------------------------ a gift of itself --

## Does [param a] hand its own source to an opponent ("Target opponent
## gains control of this creature" — Witch Engine; Goblin Festival's lost
## flip, "… gains control of this enchantment")? Read off the line after
## the cost.
static func gives_itself_away(a: ActivatedAbility) -> bool:
	var text := a.text.to_lower()
	var colon := text.find(":")
	return (text.substr(colon + 1) if colon >= 0 else text).contains("gains control of this")


## THE GIFT (Witch Engine: B9's urgent item — four black mana for a 4/4 the
## opponent keeps). Never, except for the damage riding with it that ends
## the game (Goblin Festival's ping at a player on 1).
static func gift_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		_window: String) -> Dictionary:
	var foe: int = g.opponent_of(pilot.pid)
	var face := TargetRef.player(foe)
	for e in a.effects:
		if e is DamageEffect and e.target_spec != null and e.amount > 0 \
				and e.target_spec.is_legal(g, face, s) \
				and int(g.predict_damage(s, face, e.amount, false, 0, pilot.pid)["life"]) <= 0:
			return {"value": AiPlayer.LETHAL_WORTH, "targets": [face]}
	return {}


# ------------------------------------------------------ counters cashed --

## The counter kind [param a]'s X counts on its own source ("verse",
## "page", "fuse"), or "" — read off the printed line, for an ability that
## sacrifices that source (the count is recorded with the cost, CR 608.2h).
static func counted_kind(a: ActivatedAbility) -> String:
	if not a.sacrifice_cost:
		return ""
	var line := a.text.to_lower()
	for mark in COUNTED_MARKS:
		var at := line.find(mark)
		if at < 0:
			continue
		var words := line.substr(at + mark.length()).split(" ", false)
		if words.size() >= 2 and words[1] == "counters":
			return words[0]
	return ""


## THE COUNTERS CASHED IN (B6's verse cycle, B8's Barrin's Codex and
## Powder Keg). The probe that opened this module saw Midsummer Revel and
## Rumbling Crescendo sacrificed at X = 0 for nothing, and Vile Requiem
## priced as removal with no counter on it. Each effect is cashed when its
## X covers what the board shows ([constant COVER_ENOUGH]) or the
## permanent is about to go anyway — their removal on the stack names it
## ([method TempestTactics._removal_aimed_at]) — when the sacrifice it
## would make costs nothing ([method AiPlayer._sacrifice_price] is given
## back). Torch Song's damage is the Mirage reading's (`counter_blast_option`:
## null here); Lilting Refrain and War Dance have their own moments.
static func counter_cash_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Variant:
	var e: EffectBase = a.effects[0]
	if e is DamageEffect:
		return null
	var x := int(s.counters.get(counted_kind(a), 0))
	var doomed: bool = TEMPEST_TACTICS._removal_aimed_at(g, pilot, s)
	var cash := {}
	if e is CounterEffect:
		cash = refrain_cash(g, pilot, s, e, x, window)
	elif e is PumpEffect:
		cash = dance_cash(g, pilot, s, e, x, window)
	elif e is PreventDamageEffect:
		cash = hymn_cash(g, pilot, s, e, x, window)
	else:
		if not doomed and not window in ["MAIN", "SINK", "UPKEEP"]:
			return {}
		if e.target_count_fn.is_valid():
			cash = up_to_x_cash(g, pilot, s, e, x, doomed)
		elif e is CreateTokenEffect:
			cash = beasts_cash(g, pilot, e, x, doomed)
		elif e is ChosenDiscardEffect:
			cash = dirge_cash(g, pilot, x, doomed)
		elif e is DrawEffect:
			cash = pages_cash(g, pilot, x, window, doomed)
		elif _line(e).contains("destroy each artifact and creature"):
			cash = keg_cash(g, pilot, s, x)
		else:
			return null
	if cash.is_empty():
		return {}
	if doomed:
		cash["value"] = float(cash["value"]) + float(pilot._sacrifice_price(g, s, a))
	return cash


## "Destroy / return up to X target …" (Vile Requiem, Serra's Liturgy,
## Rumbling Crescendo, Recantation): the best X of the opponent's legal
## targets, once X covers all of them or [constant COVER_ENOUGH].
static func up_to_x_cash(g: MtgGame, pilot, s: CardInstance, e: EffectBase, x: int,
		doomed: bool) -> Dictionary:
	if x <= 0 or e.target_spec == null:
		return {}
	var foe: int = g.opponent_of(pilot.pid)
	var bounce := e is ReturnToHandEffect
	var rows: Array = []
	for ref in e.target_spec.legal_targets(g, s):
		if ref.is_player:
			continue
		var inst := g.find_instance(ref.instance_id)
		if inst == null or inst.controller_id != foe or inst.zone != Mtg.Zone.BATTLEFIELD:
			continue
		var worth := 0.0
		if bounce:
			if inst.is_land():
				continue   # a land back in hand is a land drop, not tempo
			# A token returned is gone; a card is its recasting tempo.
			worth = pilot._victim_value(g, inst) if inst.is_token \
				else maxf(1.0, inst.data.cost.mana_value() * 0.75)
		elif inst.is_land():
			worth = LAND_WORTH
		elif inst.is_creature():
			worth = pilot._victim_value(g, inst)
		else:
			worth = Evaluator.permanent_value(inst, pilot.profile)
		rows.append([worth, ref])
	if rows.is_empty():
		return {}
	rows.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) > float(q[0]))
	var take := mini(x, rows.size())
	if not doomed and take < rows.size() and take < COVER_ENOUGH:
		return {}   # the next verse counter buys another target
	var value := 0.0
	var targets: Array = []
	for i in take:
		value += float(rows[i][0]) + 0.5
		targets.append(rows[i][1])
	return {"value": value, "targets": targets}


## SERRA'S HYMN ("Prevent the next X damage that would be dealt this turn
## to any number of targets, divided as you choose"). Its counted slot
## reads like the up-to-X removal above, and was cashed as one: in the
## main phase, on the opponent's creatures, one share each — prevention
## handed to their side, and refused outright whenever the shares did not
## add up to X (the Pack 10 study's audit, seed 99070). A share prevents
## damage TO its target, so only our own side is a target, and only in
## answer to damage the board shows coming — the burn on top of the stack,
## or a declared combat once the blocks are known: the whole X on the one
## target of ours where the forecast says it saves the most (one target
## absorbs the whole total, CR 601.2d), priced as that forecast's swing.
static func hymn_cash(g: MtgGame, pilot, s: CardInstance, e: PreventDamageEffect, x: int,
		window: String) -> Dictionary:
	if x <= 0 or window != "RESPONSE" or e.target_spec == null:
		return {}
	var top := g.can_forecast_damage_top()
	if not top and (g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers \
			or g.combat.attackers.is_empty()):
		return {}
	var before := g.forecast_damage(true, top)
	var best := {}
	for ref in e.target_spec.legal_targets(g, s):
		var object: Object = g.players[ref.player_id] if ref.is_player \
			else g.find_instance(ref.instance_id)
		if object == null:
			continue
		var side: int = ref.player_id if ref.is_player else (object as CardInstance).controller_id
		if side != pilot.pid:
			continue
		var nested := g.undo_log != null
		var mark := g.make_mark()
		var property := &"damage_prevention" if ref.is_player else &"prevention"
		g._rec(object, property)
		object.set(property, int(object.get(property)) + x)
		var after := g.forecast_damage(true, top)
		g.unmake_to(mark)
		if not nested: g.end_search()
		var value: float = HOMELANDS_TACTICS.swing(g, pilot, before, after)
		if value > 0.0 and (best.is_empty() or value > float(best["value"])):
			best = {"value": value, "targets": [ref]}
	return best


## Midsummer Revel's X 3/3 Beasts: three of them, or one to block with
## once their visible power threatens half our life.
static func beasts_cash(g: MtgGame, pilot, e: CreateTokenEffect, x: int,
		doomed: bool) -> Dictionary:
	if x <= 0:
		return {}
	var pressed := their_power(g, pilot) * 2 >= g.players[pilot.pid].life
	if not doomed and x < COVER_ENOUGH and not pressed:
		return {}
	return {"value": pilot._token_value({"power": e.token.power * x,
		"toughness": e.token.toughness * x}), "targets": []}


## Discordant Dirge: X covers their hand (its SIZE is public), or three
## cards of it. Which cards is decided as it resolves, with the hand
## revealed to us by the card itself.
static func dirge_cash(g: MtgGame, pilot, x: int, doomed: bool) -> Dictionary:
	var foe: int = g.opponent_of(pilot.pid)
	var held := g.players[foe].hand.size()
	if x <= 0 or held <= 0:
		return {}
	if not doomed and x < held and x < COVER_ENOUGH:
		return {}
	return {"value": DIRGE_CARD * mini(x, held), "targets": [TargetRef.player(foe)]}


## Barrin's Codex: three pages or more, as many as the hand can use.
static func pages_cash(g: MtgGame, pilot, x: int, window: String, doomed: bool) -> Dictionary:
	if x <= 0:
		return {}
	var moment: int = AiPlayer.Moment.get(window, AiPlayer.Moment.MAIN)
	var n := mini(x, pilot._hand_room(g, moment))
	if n <= 0 or (not doomed and x < COVER_ENOUGH):
		return {}
	return {"value": 2.0 * n + pilot._draw_need(g.players[pilot.pid].hand.size()), "targets": []}


## Powder Keg: every artifact and creature whose mana value is the fuse
## count, theirs against ours.
static func keg_cash(g: MtgGame, pilot, s: CardInstance, x: int) -> Dictionary:
	var theirs := 0.0
	var ours := 0.0
	for inst in g.all_battlefield():
		if inst == s or inst.phased_out:
			continue
		if not (inst.is_creature() or inst.is_type(Mtg.CardType.ARTIFACT)):
			continue
		if g.copiable_data(inst).cost.mana_value() != x:
			continue
		if inst.controller_id == pilot.pid:
			ours += pilot._own_value(g, inst)
		elif inst.is_creature():
			theirs += pilot._victim_value(g, inst)
		else:
			theirs += Evaluator.permanent_value(inst, pilot.profile)
	if theirs <= 0.0 or theirs - ours < KEG_NET:
		return {}
	return {"value": theirs - ours, "targets": []}


## Lilting Refrain: their spell on the stack, worth a card, that their
## open mana (public: their untapped sources and pool) cannot pay X for.
static func refrain_cash(g: MtgGame, pilot, s: CardInstance, e: EffectBase, x: int,
		window: String) -> Dictionary:
	if window != "RESPONSE" or x <= 0 or g.stack.is_empty():
		return {}
	var top: StackItem = g.stack.back()
	if top.controller == pilot.pid or top.kind != Mtg.StackKind.SPELL or top.card == null:
		return {}
	var ref := TargetRef.card(top.card)
	if e.target_spec == null or not e.target_spec.is_legal(g, ref, s):
		return {}
	if open_mana(g, top.controller) >= x:
		return {}   # they pay, and the Refrain is gone for nothing
	var worth := Evaluator.card_value(top.card.data)
	if worth < 3.0:
		return {}
	return {"value": worth + 1.0, "targets": [ref]}


## War Dance's +X/+X: inside a declared combat, on the creature of ours it
## saves or lets kill, or an unblocked attacker whose X ends the game.
static func dance_cash(g: MtgGame, pilot, s: CardInstance, e: EffectBase, x: int,
		window: String) -> Dictionary:
	if window != "RESPONSE" or x <= 0 or not g.stack.is_empty() \
			or g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers \
			or g.combat_damage_prevented or g.combat.attackers.is_empty():
		return {}
	var pid: int = pilot.pid
	var foe: int = g.opponent_of(pid)
	var boost := Vector2i(x, x)
	var best := {}
	for id in g.combat.attackers:
		var attacker := g.find_instance(id)
		if attacker == null or not g.is_present(attacker):
			continue
		var blockers: Array[CardInstance] = []
		for b_id in g.combat.blockers_of(attacker.id):
			var b := g.find_instance(b_id)
			if b != null and g.is_present(b):
				blockers.append(b)
		var ours := attacker if attacker.controller_id == pid else null
		var value := 0.0
		if ours != null:
			if blockers.is_empty():
				if g.active_player == pid and maxi(ours.cur_power, 0) + x >= g.players[foe].life \
						and maxi(ours.cur_power, 0) < g.players[foe].life:
					value = AiPlayer.LETHAL_WORTH
			for b in blockers:
				value += _fight_gain(g, pilot, ours, b, boost)
		else:
			for b in blockers:
				if b.controller_id == pid:
					value += _fight_gain(g, pilot, b, attacker, boost)
		if ours == null and blockers.is_empty():
			continue
		var target: CardInstance = ours
		if target == null:
			for b in blockers:
				if b.controller_id == pid:
					target = b
					break
		if target == null or value <= 0.0:
			continue
		var ref := TargetRef.card(target)
		if e.target_spec != null and not e.target_spec.is_legal(g, ref, s):
			continue
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": [ref]}
	return best


## What +[param boost] on our [param mine] fighting [param other] gains:
## the body saved and the body killed.
static func _fight_gain(g: MtgGame, pilot, mine: CardInstance, other: CardInstance,
		boost: Vector2i) -> float:
	var gain := 0.0
	if pilot._dies_to(g, mine, other) and not pilot._dies_to(g, mine, other, boost):
		gain += float(pilot._own_value(g, mine))
	if not pilot._dies_to(g, other, mine) \
			and pilot._dies_to(g, other, mine, Vector2i.ZERO, boost):
		gain += float(pilot._victim_value(g, other))
	return gain


# ------------------------------------------------- an Aura sold for a card --

## Capashen Standard, Illuminated Wings: "{2}, Sacrifice this Aura: Draw a
## card." The probe sold them in our own main phase for a card the Aura
## already was. Only when the host is about to leave (their removal names
## it or the Aura, or the declared combat kills it) — the Aura would go
## with it — or the host is THEIRS.
static func aura_cash_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	var host := g.find_instance(s.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return {}
	var pid: int = pilot.pid
	var doomed: bool = TEMPEST_TACTICS._removal_aimed_at(g, pilot, s) \
		or TEMPEST_TACTICS._removal_aimed_at(g, pilot, host) \
		or (host.controller_id == pid and dies_in_combat(g, host))
	if not doomed and host.controller_id == pid:
		return {}
	if not doomed and not window in ["MAIN", "SINK"]:
		return {}
	var value: float = 4.0 + pilot._draw_need(g.players[pid].hand.size())
	if doomed:
		value += float(pilot._sacrifice_price(g, s, a))
	return {"value": value, "targets": []}


## Does the declared combat's forecast kill [param inst] ([method
## TempestTactics.combat_forecast])?
static func dies_in_combat(g: MtgGame, inst: CardInstance) -> bool:
	if not g.combat.attackers.has(inst.id) and not g.combat.blocks.has(inst.id):
		return false
	var future: Dictionary = TEMPEST_TACTICS.combat_forecast(g)
	return not future.is_empty() and not (future["alive"] as Dictionary).has(inst.id)


# ---------------------------------------------- the life paid for a body --

## [param e]'s own line, lower case — "" for a [PumpEffect], whose
## description assumes a target a self-pump does not have (the reason
## [method CardCombos._untaps] reads the ability text instead).
static func _line(e: EffectBase) -> String:
	return "" if e == null or e is PumpEffect else e.describe().to_lower()


## "This permanent becomes an enchantment" (Opal Acrolith's {0}).
static func becomes_enchantment(a: ActivatedAbility) -> bool:
	return a.effects.size() == 1 and a.effects[0].target_spec == null \
		and _line(a.effects[0]).contains("becomes an enchantment")


## A life-cost animation of a permanent that is not a creature yet
## (Lurking Evil: "Pay half your life, rounded up: This enchantment
## becomes a 4/4 Phyrexian Horror creature with flying").
static func animates_for_life(s: CardInstance, a: ActivatedAbility) -> bool:
	if not a.has_life_cost() or a.effects.size() != 1 or a.effects[0].target_spec != null:
		return false
	var line := _line(a.effects[0])
	return line.contains("becomes a") and line.contains("creature") \
		and not line.contains("until end of turn")


## LURKING EVIL, priced by the life the engine would really take ([method
## MtgGame.ability_life_cost] — half, rounded up, worked out as it is paid;
## [member ActivatedAbility.life_cost] alone reads 0). Our first main
## phase, so the body attacks at once; refused when it already is a
## creature, and when the life left would not survive the opponent's
## visible power with [constant LIFE_MARGIN] to spare ([constant
## LIFE_FLOOR] at least). The body is the printed P/T and keywords at the
## token reader's price, less the life at the reaper's rate.
static func lurking_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	var pid: int = pilot.pid
	if s.is_creature() or window != "MAIN" or g.active_player != pid \
			or g.current_step() != Mtg.Step.MAIN1:
		return {}
	var me := g.players[pid]
	var pay: int = g.ability_life_cost(pid, s, a)
	var left := me.life - pay
	if left < LIFE_FLOOR or left <= their_power(g, pilot) + LIFE_MARGIN:
		return {}
	var line := _line(a.effects[0])
	var size := _printed_size(line)
	if size == Vector2i.ZERO:
		return {}
	var keywords: Array = []
	if line.contains("flying"):
		keywords.append(Mtg.Keyword.FLYING)
	var body: float = pilot._token_value({"power": size.x, "toughness": size.y,
		"keywords": keywords})
	return {"value": body - float(pay) * pilot._life_price(me.life), "targets": []}


## "becomes a 4/4 …" → (4, 4); zero when the line prints no size.
static func _printed_size(line: String) -> Vector2i:
	var rx := RegEx.new()
	rx.compile("(\\d+)/(\\d+)")
	var m := rx.search(line)
	return Vector2i.ZERO if m == null else Vector2i(int(m.get_string(1)), int(m.get_string(2)))


## PHYREXIAN PROCESSOR: the token is X/X for the life paid as it entered
## (`memory["paid"]`, public — the payment was announced). The shared
## token reader saw the 0/0 its typed effect prints.
static func processor_option(_g: MtgGame, pilot, s: CardInstance, window: String) -> Dictionary:
	var x := int(s.memory.get("paid", 0))
	if x <= 0 or not window in ["MAIN", "SINK"]:
		return {}
	var value: float = pilot._token_value({"power": x, "toughness": x})
	if window == "SINK":
		value += 1.0   # mana that would otherwise be lost
	return {"value": value, "targets": []}


# ------------------------------------------ a card from the hand, cheated --

## The card type [param a] puts from the hand onto the battlefield ("You
## may put a creature card from your hand onto the battlefield" — Elvish
## Piper, Quicksilver Amulet, Sneak Attack; "an artifact card" — Copper
## Gnomes), or 0.
static func from_hand_kind(a: ActivatedAbility) -> int:
	var line := a.text.to_lower()
	if line.contains("put a creature card from your hand onto the battlefield"):
		return Mtg.CardType.CREATURE
	if line.contains("put an artifact card from your hand onto the battlefield"):
		return Mtg.CardType.ARTIFACT
	return 0


## Is what [param a] puts onto the battlefield sacrificed at the next end
## step (Sneak Attack, Apprentice Necromancer)?
static func one_turn(a: ActivatedAbility) -> bool:
	var line := a.text.to_lower()
	return line.contains("at the beginning of the next end step") and line.contains("sacrifice")


## THE CARD PUT ONTO THE BATTLEFIELD (B3: Elvish Piper read only green
## creatures through Norwood Priestess's role; the card takes any). The
## best card of the kind in our own hand; in our main phase only one the
## mana on the table could not cast at once, or one that costs more than
## the ability (the mana saved); at their end step any (it arrives at
## instant speed, the untap step pays for the mana). A one-turn body is
## [method sneak_option]'s.
static func from_hand_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		kind: int, window: String) -> Dictionary:
	if one_turn(a):
		return sneak_option(g, pilot, s, a, window)
	if not window in ["MAIN", "SINK"]:
		return {}
	var pid: int = pilot.pid
	var cost := a.cost.mana_value()
	var on_table := mana_on_table(g, pilot)
	var best := {}
	for card in g.players[pid].hand:
		if not card.data.is_type(kind):
			continue
		var mv := card.data.cost.mana_value()
		if window == "MAIN" and mv <= cost and mv <= on_table:
			continue   # cast it: the ability buys nothing
		var value := Evaluator.card_value(card.data) + 0.5 * float(maxi(mv - cost, 0))
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": []}
	return best


## Sneak Attack: a creature card from our hand with haste, sacrificed at
## the next end step — a card spent on one attack. Our first main phase,
## and only for an attack the board shows ends the game or takes half of
## what is left ([method one_turn_hit]).
static func sneak_option(g: MtgGame, pilot, s: CardInstance, _a: ActivatedAbility,
		window: String) -> Dictionary:
	if not _attack_window(g, pilot, window):
		return {}
	var best := {}
	for card in g.players[pilot.pid].hand:
		if not card.data.is_creature():
			continue
		var hit := one_turn_hit(g, pilot, card.data)
		var value := _hit_value(g, pilot, hit)
		if value > 0.0 and (best.is_empty() or value > float(best["value"])):
			best = {"value": value, "targets": []}
	return best


## Does [param a] raise a creature card for one turn ("Return target
## creature card from your graveyard to the battlefield. That creature
## gains haste. At the beginning of the next end step, sacrifice it." —
## Apprentice Necromancer)? The Tempest reading would price it as a
## permanent reanimation.
static func one_turn_raise(a: ActivatedAbility) -> bool:
	return a.effects[0] is ReturnFromGraveyardEffect and one_turn(a)


static func one_turn_raise_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if not _attack_window(g, pilot, window):
		return {}
	var e: EffectBase = a.effects[0]
	var best := {}
	for ref in e.target_spec.legal_targets(g, s):
		if ref.is_player:
			continue
		var card := g.find_instance(ref.instance_id)
		if card == null or card.zone != Mtg.Zone.GRAVEYARD or not card.data.is_creature():
			continue
		var value := _hit_value(g, pilot, one_turn_hit(g, pilot, card.data))
		if value > 0.0 and (best.is_empty() or value > float(best["value"])):
			best = {"value": value, "targets": [ref]}
	return best


## Our own first main phase, the stack empty: the attack is still ahead.
static func _attack_window(g: MtgGame, pilot, window: String) -> bool:
	return window == "MAIN" and g.active_player == pilot.pid \
		and g.current_step() == Mtg.Step.MAIN1 and g.stack.is_empty() \
		and not g.no_attacks_this_turn


## The damage a hasty [param data] attacking now gets through on the
## public board: all of it when no untapped creature of theirs could block
## it (fliers by fliers and reach), the trample over their biggest
## toughness, else none. Printed size; a 0 power hits nothing.
static func one_turn_hit(g: MtgGame, pilot, data: CardData) -> int:
	var power := maxi(data.power, 0)
	if power <= 0:
		return 0
	var flies := data.has_keyword(Mtg.Keyword.FLYING)
	var wall := 0
	var blocked := false
	for b in pilot._untapped_creatures(g, g.opponent_of(pilot.pid)):
		if flies and not (b.has_keyword(Mtg.Keyword.FLYING) or b.has_keyword(Mtg.Keyword.REACH)):
			continue
		blocked = true
		wall = maxi(wall, b.cur_toughness)
	if not blocked:
		return power
	if data.has_keyword(Mtg.Keyword.TRAMPLE):
		return maxi(power - wall, 0)
	return 0


## A one-turn hit's worth: the game when it is lethal with the rest of
## our unblocked attack, its damage when it takes at least half of what
## they have left; 0 otherwise (a card is not spent on chip damage).
static func _hit_value(g: MtgGame, pilot, hit: int) -> float:
	if hit <= 0:
		return 0.0
	var foe: int = g.opponent_of(pilot.pid)
	var life := g.players[foe].life
	if hit >= life:
		return AiPlayer.LETHAL_WORTH
	if hit * 2 >= life and hit >= 4:
		return float(hit)
	return 0.0


# ------------------------------------------------------------ the untaps --

## "Untap this creature/artifact" (B9's shared self-untap).
static func untaps_itself(a: ActivatedAbility) -> bool:
	return a.effects.size() == 1 and a.effects[0].target_spec == null \
		and _line(a.effects[0]).begins_with("untap this ")


## THE SELF-UNTAP.
##  * A permanent that does not untap in its controller's untap step
##    ([member CardInstance.cur_skips_untap] — Grim Monolith, Phyrexian
##    Colossus): at their end step, with the mana the untap step would
##    waste ({4} for the Monolith's {C}{C}{C} tomorrow — never in our own
##    main phase, where {4} buys three). The Colossus's 8 life only with
##    ten life left above the opponent's visible power.
##  * A creature that untaps itself (Horseshoe Crab, Vigilant Drake,
##    Morphling…): in our second main phase, tapped from its attack, while
##    the opponent shows a creature to block — vigilance bought with mana
##    left over.
static func untap_self_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if not s.tapped:
		return {}
	var pid: int = pilot.pid
	if s.cur_skips_untap:
		if window != "SINK":
			return {}
		if a.has_life_cost():
			var left: int = g.players[pid].life - g.ability_life_cost(pid, s, a)
			if not s.is_creature() or left < 10 + their_power(g, pilot):
				return {}
			return {"value": 0.5 * float(maxi(s.cur_power, 0)), "targets": [], "bar": 0.5}
		return {"value": maxf(untapped_worth(g, pilot, s), 1.0), "targets": [], "bar": 0.5}
	if not s.is_creature() or window != "MAIN" or g.active_player != pid \
			or g.current_step() != Mtg.Step.MAIN2:
		return {}
	if g.players[g.opponent_of(pid)].creatures().is_empty():
		return {}   # nothing of theirs to stand guard against
	return {"value": 1.5 + 0.5 * float(maxi(s.cur_toughness, 0)), "targets": [], "bar": 0.5}


## What [param inst] untapped is worth for our next turn: the mana its
## abilities make, an extra turn its tap takes, or its body.
static func untapped_worth(g: MtgGame, pilot, inst: CardInstance) -> float:
	var worth := 0.0
	for m in inst.cur_mana_abilities:
		var made := 0
		for pair in m.produces:
			made += int(pair[1])
		worth = maxf(worth, float(made))
	if takes_a_turn(inst):
		worth = maxf(worth, 8.0)
	if inst.is_creature():
		worth = maxf(worth, Evaluator.permanent_value(inst, pilot.profile) * 0.5)
	return worth


## Does a {T} ability of [param inst] take an extra turn (Time Vault)?
static func takes_a_turn(inst: CardInstance) -> bool:
	for ability in inst.cur_activated_abilities:
		for e in ability.effects:
			if e is ExtraTurnEffect:
				return true
	return false


## VOLTAIC KEY ("{1}, {T}: Untap target artifact"): our tapped artifact
## that will not untap by itself, at their end step; in our own main phase
## one whose tap takes an extra turn (Time Vault — the scorer then takes
## the turn again). Never theirs; null for any other target kind.
static func untap_artifact_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Variant:
	var e: EffectBase = a.effects[0]
	var pid: int = pilot.pid
	var names_artifacts := false
	for inst in g.all_battlefield():
		if inst.is_type(Mtg.CardType.ARTIFACT) and e.target_spec.is_legal(g, TargetRef.card(inst), s):
			names_artifacts = true
			break
	if not names_artifacts:
		return null
	var best := {}
	for inst in g.players[pid].battlefield:
		if inst == s or not inst.is_type(Mtg.CardType.ARTIFACT) or not inst.tapped:
			continue
		var ref := TargetRef.card(inst)
		if not e.target_spec.is_legal(g, ref, s):
			continue
		var worth := 0.0
		if window == "SINK" and inst.cur_skips_untap:
			worth = untapped_worth(g, pilot, inst)
		elif window == "MAIN" and g.active_player == pid and takes_a_turn(inst):
			worth = 8.0
		if worth > 0.0 and (best.is_empty() or worth > float(best["value"])):
			best = {"value": worth, "targets": [ref], "bar": 0.5}
	return best


# ---------------------------------------------------- pings and shrinks --

## A repeatable ping at a creature: "{c}: N damage to target creature"
## with no {T} and no other cost (Masticore). The effect is the shared
## [DamageEffect] itself, not a card's subclass of it: a subclass does
## more than the damage — Splintering Wind's makes a Splinter each ping,
## a cumulative-upkeep flier that hits us and each of our creatures as it
## leaves, and three pings at a Hill Giant were three Splinters (the
## 0.60.19 bug pass, h5-5) — and a counter removed from the source (Spitting
## Hydra's +1/+1) is a cost beyond the mana.
static func repeat_ping(a: ActivatedAbility) -> bool:
	if a.tap_cost or a.sacrifice_cost or a.sacrifice_filter.is_valid() \
			or a.has_life_cost() or a.counter_cost_kind != "" \
			or a.effects.size() != 1 or a.cost.mana_value() <= 0:
		return false
	var e: EffectBase = a.effects[0]
	return e.get_script() == DamageEffect and e.amount > 0 and not e.use_x and e.target_spec != null \
		and e.target_spec.kind == TargetSpec.Kind.CREATURE and e.divided_total == 0


## MASTICORE'S PINGS. The shared reader kills what one ping kills; this
## one finishes what several pings kill, when the mana on the table pays
## for every shot (a first ping the mana cannot follow up is a waste), and
## a creature it already marked. Each act is one ping; the next act reads
## the damage it left. Priced as the victim less the later shots' mana.
static func repeat_ping_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Variant:
	if not window in ["MAIN", "SINK"]:
		return null
	var e: EffectBase = a.effects[0]
	var cost := a.cost.mana_value()
	var shots_on_table: int = mana_on_table(g, pilot) / cost
	var best: Variant = null
	for victim in g.players[g.opponent_of(pilot.pid)].battlefield:
		if not victim.is_creature() or victim.cur_indestructible or victim.regeneration_shields > 0:
			continue
		var ref := TargetRef.card(victim)
		if not e.target_spec.is_legal(g, ref, s):
			continue
		var landed := int(g.predict_damage(s, ref, e.amount, false, 0, pilot.pid)["dealt"])
		if landed <= 0:
			continue
		var left := victim.cur_toughness - victim.damage
		var shots := ceili(float(left) / float(landed))
		if shots <= 1 and victim.damage <= 0:
			continue   # one shot kills: the shared reader's
		if shots > shots_on_table:
			continue
		var value: float = pilot._victim_value(g, victim) + 1.0 \
			- float(maxi(shots - 1, 0) * cost) * 0.5
		if value > 0.0 and (best == null or value > float(best["value"])):
			best = {"value": value, "targets": [ref]}
	return best


## A -N/-N on a target creature that kills one of theirs (Phyrexian
## Debaser, Defiler, Denouncer, Plaguelord): the shared scorer has no arm
## for a shrink, so these were never used. The victim is their creature
## the toughness loss kills; the sacrifice (itself, or a creature — the
## Plaguelord's second) is charged by [method AiPlayer._sacrifice_price].
## Inside our own declared fight the Tempest reading decides; in any other
## response only when the source is about to go anyway.
static func shrink_kill_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Variant:
	var pid: int = pilot.pid
	if window == "PRE_ATTACK":
		return null
	if window == "RESPONSE" and g.active_player == pid \
			and g.current_step() == Mtg.Step.DECLARE_BLOCKERS and not g.combat.attackers.is_empty():
		return null   # tempest_tactics.gd `shrink_blocker_option`
	var doomed: bool = TEMPEST_TACTICS._removal_aimed_at(g, pilot, s)
	if window == "RESPONSE" and not doomed:
		return {}
	var e: PumpEffect = a.effects[0]
	var best := {}
	for victim in g.players[g.opponent_of(pid)].battlefield:
		if not victim.is_creature():
			continue
		var ref := TargetRef.card(victim)
		if not e.target_spec.is_legal(g, ref, s):
			continue
		var toughness := victim.cur_toughness + e.toughness
		if toughness > 0 and (toughness > victim.damage or victim.cur_indestructible
				or victim.regeneration_shields > 0):
			continue
		var value: float = pilot._victim_value(g, victim) + 1.0
		if doomed and a.sacrifice_cost:
			value += float(pilot._sacrifice_price(g, s, a))
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": [ref]}
	return best


## THE SHOT AT A CREATURE IN COMBAT ("deals N damage to target attacking
## or blocking creature" — Elite Archers, Expendable Troops). The shared
## scorer never fires in a combat window, so these were never shot: in a
## declared combat, their attacker or blocker the damage kills (the
## engine's own prediction), at the victim's worth; the sacrifice
## (Expendable Troops) is charged by the shared scorer.
static func combat_shot_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if not window in ["RESPONSE", "COMBAT"] or g.combat.attackers.is_empty() \
			or g.combat_damage_prevented:
		return {}
	var e: EffectBase = a.effects[0]
	var best := {}
	for ref in e.target_spec.legal_targets(g, s):
		if ref.is_player:
			continue
		var victim := g.find_instance(ref.instance_id)
		if victim == null or victim.controller_id == pilot.pid:
			continue
		if not bool(g.predict_damage(s, ref, e.amount, false, 0, pilot.pid)["dies"]):
			continue
		var value: float = pilot._victim_value(g, victim) + 1.0
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": [ref]}
	return best


## "deals N damage to each opponent" (Shivan Gorge), read off the printed
## line: N, or 0.
static func each_opponent_damage(a: ActivatedAbility) -> int:
	var rx := RegEx.new()
	rx.compile("deals (\\d+) damage to each opponent")
	var m := rx.search(a.text.to_lower())
	return 0 if m == null else int(m.get_string(1))


## A toll at their face: with their end step's spare mana, or whenever it
## is lethal.
static func toll_option(g: MtgGame, pilot, n: int, window: String) -> Dictionary:
	var foe: int = g.opponent_of(pilot.pid)
	if n >= g.players[foe].life:
		return {"value": AiPlayer.LETHAL_WORTH, "targets": []}
	if window != "SINK":
		return {}
	return {"value": pilot._face_damage_value(g, n, foe) + 1.0, "targets": [], "bar": 0.5}


# --------------------------------------------------------- the Bargain --

## "Pay 1 life: Draw a card." (Yawgmoth's Bargain).
static func bargain(a: ActivatedAbility) -> bool:
	return a.has_life_cost() and a.effects.size() == 1 and a.effects[0] is DrawEffect \
		and a.cost.mana_value() == 0 and not a.tap_cost


## THE BARGAIN'S FLOOR (the Necropotence reading): a card for a life only
## while the life left stays above twice the opponent's visible power and
## a burn spell; above it, the shared draw reader prices the card with the
## life it costs ([method MtgGame.ability_life_cost]).
static func bargain_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility) -> Variant:
	var pid: int = pilot.pid
	var left: int = g.players[pid].life - g.ability_life_cost(pid, s, a)
	if left < their_power(g, pilot) * 2 + 4:
		return {}
	return null


# ======================================================= the main phase --

## THE MAIN-PHASE ARM, asked by [method MirageTactics.lion_eye_action] in
## our main phase (beside the Tempest module's): one special action, or "".
static func main_action(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	return damping_action(g, pilot)


## DAMPING ENGINE'S IGNORE (CR 116.2d, the special action "Sacrifice a
## permanent: ignore this effect until end of turn"): taken in our main
## phase when the ban stops a card of our own hand we would then play — a
## land with the drop unused, a spell the pilot casts — worth more than
## the permanent the cost takes. Never for an Aura's curse (Volrath's
## Curse is the Tempest module's).
##
## THE BODY IS PRICED GONE (the 0.60.19 bug pass, h5-1; the Pack 9 curse's
## lesson, [method TempestTactics.curse_action]). The probe sacrificed the
## Mountain a Shivan Dragon needed and cast nothing, a land for a Gilded
## Drake with nothing of theirs to take, and a land while our own Engine —
## the lock itself — stayed. So each body is tried in [method
## _ignore_order]'s order: under the search journal the ignore is recorded
## and that body sacrificed, and only then is the hand read ([method
## _ignored_gain]). The cost question is then answered with that body.
static func damping_action(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	if g.active_player != pid or not Mtg.is_main_step(g.current_step()) or not g.stack.is_empty():
		return ""
	var rows: Array[Dictionary] = g.special_actions(pid)
	for row in rows:
		if String(row.get("kind", "")) != "ignore_effect":
			continue
		var engine: CardInstance = row.get("card")
		if engine == null or engine.data.is_aura() or g.special_action_refusal(pid, row) != "":
			continue
		var stopped: Array[CardInstance] = []
		var most := 0.0   # the most any stopped card could gain
		for card in g.players[pid].hand:
			if g.play_banned(pid, card.data) == "":
				continue
			stopped.append(card)
			most = maxf(most, LAND_WORTH if card.is_land() else Evaluator.card_value(card.data))
		if stopped.is_empty():
			continue
		for pair in _ignore_order(g, pilot, engine, rows):
			var body: CardInstance = pair[1]
			var price: float = pair[0]
			if most <= price + 1.0:
				break   # the dearer bodies after it cannot pay either
			if _ignored_gain(g, pilot, engine, body, stopped) <= price + 1.0:
				continue
			# The cost question is ours to answer ([method AiPlayer.answer_card]
			# pays a cost with the cheapest body it is not told to spare): every
			# other body is spared, so the body paid is the body priced.
			var saved: Dictionary = pilot._cost_spares
			var spared := {}
			for other in g._ignore_bodies(pid, engine):
				if other != body:
					spared[other.id] = true
			pilot._cost_spares = spared
			var done: String = TEMPEST_TACTICS.take_special(g, pid, "ignore_effect", engine.id)
			pilot._cost_spares = saved
			if done != "":
				return "ignores %s: %s" % [engine.data.card_name, done]
			break
	return ""


## The bodies the ignore of [param engine] may give up, `[price, body]`,
## cheapest first, at most [constant IGNORE_TRIES]: a LOCK ON US first —
## a permanent of ours whose own effect we are offered to ignore (our own
## Damping Engine, binding us for being ahead on permanents: [param rows]
## lists it) stops only us, so it is priced at nothing — then the rest by
## [method AiPlayer._own_value].
static func _ignore_order(g: MtgGame, pilot, engine: CardInstance, rows: Array) -> Array:
	var locks := {}
	for row in rows:
		if String(row.get("kind", "")) == "ignore_effect":
			locks[int(row.get("id", -1))] = true
	var out: Array = []
	for body in g._ignore_bodies(pilot.pid, engine):
		out.append([0.0 if locks.has(body.id) else float(pilot._own_value(g, body)), body])
	out.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	return out.slice(0, IGNORE_TRIES)


## What ignoring [param engine] by sacrificing [param body] gains, read
## after it under the search journal: the best card of [param stopped] (our
## hand the ban stopped) that no ban stops any more and that is then a
## land drop ([constant LAND_WORTH]) or a spell [method
## AiPlayer._plan_spell_choice] casts with the mana left — its card's
## worth; never a copy of the body itself (the duel audit's Burn deck gave
## up a Torch Song to cast its twin). 0.0 for none.
static func _ignored_gain(g: MtgGame, pilot, engine: CardInstance, body: CardInstance,
		stopped: Array[CardInstance]) -> float:
	var pid: int = pilot.pid
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g._rec(engine, &"memory")
	var ignored: Dictionary = {}
	if engine.memory.get("ignored") is Dictionary:
		ignored = (engine.memory["ignored"] as Dictionary).duplicate()
	ignored[pid] = g.turn_number
	engine.memory["ignored"] = ignored
	g.sacrifice_permanent(body)
	g.recalculate()
	var gained := 0.0
	for card in stopped:
		if card.zone != Mtg.Zone.HAND or g.play_banned(pid, card.data) != "":
			continue
		if card.data.card_name == body.data.card_name:
			continue   # the body's own twin: a Torch Song given up to cast a Torch Song buys nothing
		if card.is_land():
			if g.land_drop_available(pid):
				gained = maxf(gained, LAND_WORTH)
			continue
		var max_x := 0
		if card.data.cost.has_x:
			max_x = pilot._max_affordable_x(g, card.data.cost, g.spell_surcharge(pid, card.data),
				pilot._mana_sources(g), card.data.x_color, g.mana_usage_keys(card.data, card))
		if not (pilot._plan_spell_choice(g, card, max_x) as Dictionary).is_empty():
			gained = maxf(gained, Evaluator.card_value(card.data))
	g.unmake_to(mark)
	if not nested:
		g.end_search()
	return gained


# ========================================================= the responses --

## THE RESPONSE ARM, asked by [method MirageTactics.respond] (which runs
## only where [method AiPlayer._respond_action] runs): one action, or "".
static func respond(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	return opal_dodge(g, pilot)


## OPAL ACROLITH'S DODGE ("{0}: This permanent becomes an enchantment"):
## the creature our opponent's removal on the stack names, a sweeper of
## theirs would kill, or the declared combat kills, becomes an enchantment
## first — a creature-only target is gone (CR 608.2b) and a permanent that
## stops being a creature leaves combat (CR 506.4). Never otherwise: the
## body is what blocks.
static func opal_dodge(g: MtgGame, pilot) -> String:
	for s in g.players[pilot.pid].battlefield:
		if not s.is_creature() or s.phased_out:
			continue
		for index in s.cur_activated_abilities.size():
			if not becomes_enchantment(s.cur_activated_abilities[index]):
				continue
			if not TEMPEST_TACTICS.ability_ready(g, pilot, s, index):
				continue
			if TEMPEST_TACTICS._removal_aimed_at(g, pilot, s) \
					or (g.stack.is_empty() and dies_in_combat(g, s)):
				return TEMPEST_TACTICS.activate_direct(g, pilot, s, index, [],
					"becomes an enchantment out of harm's way")
	return ""


# ============================================================== combat --

## A creature that changes sides when it blocks or becomes blocked
## (Goblin Cadets: "Whenever this creature blocks or becomes blocked,
## target opponent gains control of it").
static func defects_in_combat(inst: CardInstance) -> bool:
	for t in inst.cur_triggered_abilities:
		var line := t.text.to_lower()
		if line.contains("blocks or becomes blocked") and line.contains("gains control of it"):
			return true
	return false


## A creature that costs its controller a permanent for each point it is
## dealt (Phyrexian Negator: "Whenever this creature is dealt damage,
## sacrifice that many permanents").
static func damage_costs_permanents(inst: CardInstance) -> bool:
	for t in inst.cur_triggered_abilities:
		var line := t.text.to_lower()
		if line.contains("is dealt damage") and line.contains("sacrifice that many permanents"):
			return true
	return false


## OUR ATTACK, asked by [method MirageTactics.price_forced_attackers] before
## the requirement repairs: a defector stays home while any untapped
## creature of theirs could block it (the block hands it to them), and so
## does a Negator any of their untapped creatures with power could block —
## unless the swing as declared is lethal on the public board.
static func price_attackers(g: MtgGame, pilot, attackers: Array, defender: int) -> Array:
	if not pilot.profile.forecasts_tactics or attackers.is_empty():
		return attackers
	var blockers: Array[CardInstance] = pilot._untapped_creatures(g, defender)
	if blockers.is_empty() or _lethal_past_blocks(g, attackers, blockers.size(),
			g.players[defender].life):
		return attackers
	var out: Array = []
	for id in attackers:
		var inst := g.find_instance(int(id))
		if inst != null and not AiPlayer._must_attack(inst) \
				and (defects_in_combat(inst) or damage_costs_permanents(inst)):
			var hurting: Array[CardInstance] = blockers
			if damage_costs_permanents(inst):
				hurting = blockers.filter(func(b: CardInstance) -> bool: return b.cur_power > 0)
			if TEMPEST_TACTICS._blockable_by(g, inst, hurting, defender, pilot.pid):
				continue
		out.append(id)
	return out


## OUR BLOCKS, asked by [method MirageTactics.price_block_tax]: a defector
## does not block (it is theirs the moment it does), and a Negator does
## not block anything with power — unless the attack as declared is
## lethal without that block.
static func price_blocks(g: MtgGame, pilot, block_map: Dictionary) -> Dictionary:
	if not pilot.profile.forecasts_tactics or block_map.is_empty():
		return block_map
	var through_all := 0
	for id in g.combat.attackers:
		var attacker := g.find_instance(id)
		if attacker != null and g.is_present(attacker):
			through_all += maxi(attacker.cur_power, 0)
	if through_all >= g.players[pilot.pid].life:
		return block_map
	var out := block_map.duplicate(true)
	for blocker_id in block_map.keys():
		var blocker := g.find_instance(int(blocker_id))
		if blocker == null:
			continue
		if defects_in_combat(blocker):
			out.erase(blocker_id)
			continue
		if damage_costs_permanents(blocker):
			var value: Variant = block_map[blocker_id]
			var against: Array = value if value is Array else [value]
			for t in against:
				var a := g.find_instance(int(t))
				if a != null and a.cur_power > 0:
					out.erase(blocker_id)
					break
	return out


# ============================================================= readings --

## The opponent's visible power: every creature they control (each may
## swing next turn), never below 0 a body.
static func their_power(g: MtgGame, pilot) -> int:
	var n := 0
	for inst in g.players[g.opponent_of(pilot.pid)].battlefield:
		if inst.is_creature() and not inst.phased_out:
			n += maxi(inst.cur_power, 0)
	return n


## Is [param attackers]' swing lethal even when [param blockers] of
## theirs each stop one of its biggest bodies?
static func _lethal_past_blocks(g: MtgGame, attackers: Array, blockers: int, life: int) -> bool:
	var powers: Array[int] = []
	for id in attackers:
		var inst := g.find_instance(int(id))
		if inst != null:
			powers.append(maxi(inst.cur_power, 0))
	powers.sort()
	powers.reverse()
	var through := 0
	for i in range(mini(blockers, powers.size()), powers.size()):
		through += powers[i]
	return through >= life


## The mana [param pilot] can make now: the pool and every untapped
## source the planner sees ([method rows_mana]).
static func mana_on_table(g: MtgGame, pilot) -> int:
	return g.players[pilot.pid].mana_pool.total() + rows_mana(pilot._mana_sources(g))


## [param pid]'s open mana on the public board: the pool and the untapped
## sources ([method ManaPlanner.sources], read as the opponent sees them).
static func open_mana(g: MtgGame, pid: int) -> int:
	return g.players[pid].mana_pool.total() \
		+ rows_mana(ManaPlanner.sources(g, pid, {}, false, g.opponent_of(pid)))


## The mana the planner's source [param rows] make together, EACH SOURCE
## ONCE. The planner lists a dual land once per ability and an any-color
## source (City of Brass, Birds of Paradise) once per color, and its plans
## tap each instance once ([method ManaPlanner.source_key]); summed row by
## row, four Volcanic Islands were eight mana and two Cities ten (the
## 0.60.19 bug pass, h5-2). A source is its biggest row — every output of
## a coupled row ([method AiPlayer._row_output]) — less the mana a
## converting row takes in. Floating rows (a null instance) only with
## [param floating]; [method mana_on_table] reads the pool's own total.
static func rows_mana(rows: Array, floating := false) -> int:
	var best: Dictionary = {}
	for row in rows:
		if row[0] == null and not floating:
			continue
		var made: int = AiPlayer._row_output(row)
		if row.size() > 8 and row[8] is Dictionary and row[8].get("cost") is ManaCost:
			made -= (row[8]["cost"] as ManaCost).mana_value()
		var key := ManaPlanner.source_key(row)
		best[key] = maxi(int(best.get(key, 0)), maxi(made, 0))
	var n := 0
	for key in best:
		n += int(best[key])
	return n
