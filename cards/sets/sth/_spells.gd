extends RefCounted
## Stronghold (_spells, Pack 9). Instants and sorceries: one-shot spell effects, modes, X spells and their targets.
##
## - Bandage / Temper are prevention spells, legal in the 1997
##   damage-prevention window: every effect carries is_damage_prevention
##   (Bandage's draw too — the window admits a spell only when all of its
##   effects are of the family). Temper is one metered entry of the damage
##   suite (MtgGame.add_damage_effect, kind prevent, X points, this turn)
##   whose `then` rider puts one +1/+1 counter on the creature for each
##   point it actually prevented (CR 615.5), as the damage is prevented.
## - Cannibalize: ONE targeting effect taking two creatures (CR 115.3, two
##   different ones) whose second must share the first's controller
##   (sibling filter within the group). The caster chooses which one is
##   exiled as the spell resolves (CR 608.2d); an illegal target is
##   unaffected (CR 608.2b), so with one left the caster chooses whether
##   it is the exiled one or the one that grows.
## - Elven Rite divides two counters among one or two targets as it is
##   cast (CR 601.2d); a target that became illegal loses its share.
## - Mogg Infestation counts the creatures that DIED in its own
##   destruction (MtgGame.deaths_this_turn rows made inside its bracket):
##   a regenerated creature, or one whose death was replaced, did not;
##   a token did (CR 700.4, 111.7). The tokens are that player's.
## - Rebound: a spell with exactly one target, a player; the new target is
##   another legal PLAYER for it (CR 115.7a — when there is none, nothing
##   changes).
## - Reins of Power: the two sets are fixed as it resolves (CR 611.2c) —
##   a creature arriving later is unaffected. The exchange is two
##   until-end-of-turn control effects; haste for the turn on each.
## tests/cards/test_pack_9_B10_spells.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const DEFLECT := preload("res://cards/sets/ice/_patterns.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Bandage":
			c.spell(PreventDamageEffect.new(1).any_target())
			c.spell(DrawEffect.new(1).as_damage_prevention())
		"Cannibalize":
			c.spell(Cannibalize.new())
		"Crossbow Ambush":
			c.spell(MassPumpEffect.new(0, 0, "creatures you control", [Mtg.Keyword.REACH]).yours_only())
		"Death Stroke":
			c.spell(DestroyEffect.new(TargetSpec.creature("target tapped creature", _tapped).because("tapped")))
		"Elven Rite":
			c.spell(ElvenRite.new())
		"Evacuation":
			c.spell(F.Action.new(_evacuation, "return all creatures to their owners' hands") \
				.with_ai_role(&"mass_bounce"))
		"Flame Wave":
			c.spell(FlameWave.new())
		"Leap":
			c.spell(PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]))
			c.spell(DrawEffect.new(1))
		"Mana Leak":
			c.spell(F.TollCounter.new("{3}"))
		"Mob Justice":
			c.spell(MobJustice.new())
		"Mogg Infestation":
			c.spell(F.Action.new(_infestation,
				"destroy all creatures target player controls; for each creature that died this way, that player creates two 1/1 red Goblin creature tokens",
				TargetSpec.player()).with_ai_role(&"player_creature_sweep", {"tokens_each": 2}))
		"Rebound":
			c.spell(F.Action.new(_rebound,
				"change the target of target spell that targets only a player; the new target must be a player",
				TargetSpec.spell("target spell that targets only a player").with_game_filter(_targets_only_a_player) \
					.because("target_player")).with_ai_role(&"retarget_player_spell"))
		"Reins of Power":
			c.spell(F.Action.new(_reins,
				"untap all creatures you and target opponent control; exchange control of them until end of turn; they gain haste",
				TargetSpec.opponent()).with_ai_role(&"swap_creatures_until_eot"))
		"Ruination":
			c.spell(DestroyAllEffect.new("all nonbasic lands", _nonbasic_land))
		"Shock":
			c.spell(DamageEffect.new(2).any_target())
		"Sift":
			c.spell(Sift.new())
		"Smite":
			c.spell(DestroyEffect.new(TargetSpec.creature("target blocked creature") \
				.with_game_filter(_blocked).because("blocked")))
		"Temper":
			c.spell(Temper.new())
		_: return false
	return true


static func _tapped(i: CardInstance) -> bool: return i.tapped
static func _nonbasic_land(i: CardInstance) -> bool:
	return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) == 0

## "Blocked creature": an attacking creature that became blocked this
## combat — it stays blocked even if its blockers are gone (CR 509.1h).
static func _blocked(g: MtgGame, i: CardInstance) -> bool:
	return g.combat.attackers.has(i.id) and g.combat.blocked_attackers.has(i.id)

## APNAP order (CR 101.4): the active player first.
static func _apnap(g: MtgGame) -> Array[int]:
	var out: Array[int] = []
	for k in g.players.size():
		out.append((g.active_player + k) % g.players.size())
	return out


# ---------------------------------------------------------------- Cannibalize --

## "Choose two target creatures controlled by the same player. Exile one of
## those creatures and put two +1/+1 counters on the other." An ExileEffect
## for the AI's readers (it removes the creature it names).
class Cannibalize extends ExileEffect:
	const MODES: Array[String] = ["Exile it", "Put two +1/+1 counters on it"]
	func _init() -> void:
		super(TargetSpec.creature("two target creatures controlled by the same player") \
			.with_sibling_filter(_same_controller, TargetSpec.WHY["controller"]))
		target_spec.compare_within_group = true
		target_min = 2
		target_max = 2
		with_ai_role(&"exile_one_grow_other", {"counters": 2})
	static func _same_controller(g: MtgGame, _s: CardInstance, ref: TargetRef, earlier: Array) -> bool:
		if earlier.is_empty() or ref.is_player: return true
		var first: TargetRef = earlier[0]
		if first == null or first.is_player: return false
		var a := g.find_instance(first.instance_id)
		var b := g.find_instance(ref.instance_id)
		return a != null and b != null and a.controller_id == b.controller_id
	static func _worth(i: CardInstance) -> int:
		return maxi(i.cur_power, 0) + maxi(i.cur_toughness, 0) + i.data.cost.mana_value()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		resolve_multi(g, s, pid, [t] if t != null else [], x)
	func resolve_multi(game: MtgGame, _source: CardInstance, controller: int,
			targets: Array, _x_value: int = 0) -> void:
		var live: Array[CardInstance] = []
		for ref in targets:
			if ref == null or ref.is_player: continue
			var i := game.find_instance(ref.instance_id)
			if game.is_present(i): live.append(i)
		# The second must still share the first's controller (CR 608.2b,
		# judged in slot order like the declaration).
		if live.size() == 2 and live[0].controller_id != live[1].controller_id:
			live.resize(1)
		if live.is_empty(): return
		var doomed: CardInstance = null
		var grown: CardInstance = null
		if live.size() == 1:
			var only := live[0]
			# Hint: an opponent's creature is exiled, one's own grows.
			var hint := 1 if only.controller_id == controller else 0
			var pick := game.agents[controller].choose_option(game, controller, MODES,
				"Cannibalize: what happens to %s?" % only.data.card_name, hint)
			if pick == 0: doomed = only
			else: grown = only
		else:
			# Hint: the opponent's better creature is exiled; of one's own,
			# the lesser one is, and the better one grows.
			var ranked: Array[CardInstance] = live.duplicate()
			var theirs := live[0].controller_id != controller
			ranked.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
				var wa := _worth(a)
				var wb := _worth(b)
				if wa != wb: return wa > wb if theirs else wa < wb
				return a.id < b.id)
			doomed = game.agents[controller].choose_card(game, controller, ranked,
				"Cannibalize: choose the creature to exile", false, false, true)
			if doomed == null or not ranked.has(doomed): doomed = ranked[0]
			grown = live[1] if doomed == live[0] else live[0]
		if doomed != null:
			game.exile_permanent(doomed)
		if grown != null and game.is_present(grown):
			game.add_counters(grown, "+1/+1", 2)
	func describe() -> String:
		return "choose two target creatures controlled by the same player; exile one and put two +1/+1 counters on the other"


# ---------------------------------------------------------------- Elven Rite --

## "Distribute two +1/+1 counters among one or two target creatures."
class ElvenRite extends CounterMarkerEffect:
	func _init() -> void:
		super("+1/+1", 2, TargetSpec.creature("one or two target creatures"))
		divided_among(2)
		target_max = 2
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		resolve_multi(g, s, pid, [t] if t != null else [], x)
	func resolve_multi(game: MtgGame, _source: CardInstance, _controller: int,
			targets: Array, _x_value: int = 0) -> void:
		for ref in targets:
			if ref == null or ref.is_player: continue
			var i := game.find_instance(ref.instance_id)
			var share: int = ref.amount if ref.amount > 0 else count
			if game.is_present(i): game.add_counters(i, kind, share)
	func describe() -> String:
		return "distribute two +1/+1 counters among one or two target creatures"


# ---------------------------------------------------------------- Evacuation --

## Every creature at once (one bracket, CR 704.3 — nothing is checked
## until all of them have left).
static func _evacuation(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var leaving: Array[CardInstance] = []
	for i in g.all_battlefield():
		if i.is_creature(): leaving.append(i)
	if leaving.is_empty(): return
	g.begin_simultaneous()
	for i in leaving:
		if g.is_present(i): g.return_to_hand(i)
	g.end_simultaneous()


# ---------------------------------------------------------------- Flame Wave --

## "Flame Wave deals 4 damage to target player and each creature that
## player controls" — one damage event (CR 120.3); the creatures are the
## ones that player controls as it resolves.
class FlameWave extends DamageEffect:
	func _init() -> void:
		super(4)
		target_player()
		with_ai_role(&"player_and_creatures_burn", {"amount": 4})
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or not t.is_player: return
		var victims: Array[CardInstance] = []
		for i in g.players[t.player_id].battlefield:
			if i.is_creature(): victims.append(i)
		g.begin_simultaneous()
		g.deal_damage(s, TargetRef.player(t.player_id), amount)
		for i in victims:
			if g.is_present(i): g.deal_damage(s, TargetRef.card(i), amount)
		g.end_simultaneous()
	func describe() -> String:
		return "deals 4 damage to target player and each creature that player controls"


# --------------------------------------------------------------- Mob Justice --

## X = the creatures you control as it resolves (CR 608.2h).
class MobJustice extends DamageEffect:
	func _init() -> void:
		super(0)
		target_player()
		with_ai_role(&"burn_per_creature_you_control")
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or not t.is_player: return
		var n := 0
		for i in g.players[pid].battlefield:
			if i.is_creature(): n += 1
		if n > 0: g.deal_damage(s, t, n)
	func describe() -> String:
		return "deals damage to target player equal to the number of creatures you control"


# ---------------------------------------------------------- Mogg Infestation --

static func _infestation(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if t == null or not t.is_player: return
	var who := t.player_id
	var victims: Array[CardInstance] = []
	var ids := {}
	for i in g.players[who].battlefield:
		if i.is_creature():
			victims.append(i)
			ids[i.id] = true
	if victims.is_empty(): return
	var before := g.deaths_this_turn.size()
	g.begin_simultaneous()
	for i in victims:
		if g.is_present(i): g.destroy(i)
	# Read inside the bracket: only this destruction's deaths, before any
	# state-based action the sweep sets off (CR 704.3).
	var died := 0
	for k in range(before, g.deaths_this_turn.size()):
		if ids.has(int(g.deaths_this_turn[k].get("id", -1))): died += 1
	g.end_simultaneous()
	if died <= 0: return
	var goblin := CardData.new("Goblin", "", Mtg.CardType.CREATURE).pt(1, 1) \
		.with_colors(Mtg.ManaColor.R).with_subtypes(["goblin"])
	g.create_token(who, goblin, 2 * died)


# ------------------------------------------------------------------- Rebound --

static func _targets_only_a_player(g: MtgGame, i: CardInstance) -> bool:
	var item := g.find_stack_item(i)
	return item != null and item.kind == Mtg.StackKind.SPELL and item.targets.size() == 1 \
		and item.targets[0] != null and item.targets[0].is_player

static func _rebound(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	if t == null or t.is_player: return
	var spell := g.find_instance(t.instance_id)
	if spell == null: return
	var candidates: Array[TargetRef] = []
	for ref in g.single_spell_retargets(spell):
		if ref.is_player: candidates.append(ref)
	if candidates.is_empty():
		g.log_line("Rebound: %s has no other player to target" % spell.data.card_name)
		return
	var labels: Array[String] = []
	var best := 0
	var value := -INF
	for n in candidates.size():
		labels.append(g.players[candidates[n].player_id].player_name)
		var score: float = DEFLECT.retarget_value(g, pid, spell, candidates[n])
		if score > value:
			value = score
			best = n
	var at := g.agents[pid].choose_option(g, pid, labels, "Rebound: choose the spell's new target", best)
	if at >= 0 and at < candidates.size():
		g.retarget_spell(spell, 0, candidates[at])


# ------------------------------------------------------------ Reins of Power --

static func _reins(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	if t == null or not t.is_player or t.player_id == pid: return
	var opponent := t.player_id
	var mine: Array[CardInstance] = []
	var theirs: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_creature(): mine.append(i)
	for i in g.players[opponent].battlefield:
		if i.is_creature(): theirs.append(i)
	var all: Array[CardInstance] = mine.duplicate()
	all.append_array(theirs)
	if all.is_empty(): return
	g.begin_simultaneous()
	for i in all: g.untap_permanent(i)
	for i in mine:
		if g.is_present(i): g.gain_control_until_eot(i, opponent)
	for i in theirs:
		if g.is_present(i): g.gain_control_until_eot(i, pid)
	g.end_simultaneous()
	for i in all:
		if g.is_present(i): g.continuous.add_until_eot_keywords(i.id, [Mtg.Keyword.HASTE])
	g.recalculate()


# ---------------------------------------------------------------------- Sift --

## "Draw three cards, then discard a card." A DrawEffect for the AI's eyes.
class Sift extends DrawEffect:
	func _init() -> void:
		super(3)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		g.draw_cards(pid, 3)
		if g.players[pid].hand.is_empty(): return
		var chosen := g.agents[pid].choose_discard(g, pid, 1)
		if chosen.is_empty() or not g.players[pid].hand.has(chosen[0]):
			chosen = [g.players[pid].hand[-1]]
		g.discard_cards(pid, chosen)
	func describe() -> String:
		return "draw three cards, then discard a card"


# -------------------------------------------------------------------- Temper --

## "Prevent the next X damage that would be dealt to target creature this
## turn. For each 1 damage prevented this way, put a +1/+1 counter on that
## creature."
class Temper extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()
		is_damage_prevention = true
		ai_helpful = true
		with_ai_role(&"prevent_damage_grow", {"uses_x": true})
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		if t == null or x <= 0: return
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		var module: GDScript = load("res://cards/sets/sth/_spells.gd")
		g.add_damage_effect({"kind": &"prevent", "points": x, "victims": [i],
			"controller": pid, "card": "Temper",
			"then": module.temper_grow.bind(i.id, i.layer_timestamp),
			"desc": "Temper: prevent the next %d damage to %s" % [x, i.data.card_name]})
		g.log_line("Temper: the next %d damage to %s this turn will be prevented" % [x, i.data.card_name])
	func describe() -> String:
		return "prevent the next X damage that would be dealt to target creature this turn; a +1/+1 counter for each 1 prevented"

## Temper's rider (CR 615.5): one counter per point it prevented, on the
## creature it protects while it is still that object.
static func temper_grow(g: MtgGame, _packet: DamagePacket, prevented: int, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if prevented > 0 and g.is_present(i) and i.layer_timestamp == stamp:
		g.add_counters(i, "+1/+1", prevented)
