extends RefCounted
## Urza's Saga (_untap, Pack 10). Spells and abilities that untap lands or
## permanents.
##
## UNTAP UP TO N LANDS — [UntapUpToEffect], shared by the whole block
## (ulg/_untap.gd, uds/_untap.gd and ulg/_cycling.gd's Cloud of Faeries
## preload this file). "Untap up to N lands" targets nothing: as the spell
## or ability resolves, its controller chooses any number of lands from zero
## to N, either player's (CR 608.2d), and those untap (MtgGame.untap_permanent
## — an effect, so Winter Orb-style untap-step caps never apply). Untapping
## an untapped land changes nothing, so only TAPPED lands are offered, and
## the choice is put as two questions: how many (the seat's number), then
## that many lands, one at a time. The lands come ranked for the chooser —
## their own first, the one that makes the most mana first (Tolarian
## Academy before an Island) — so the heuristic and the computer untap
## their own lands and never an opponent's, and the hint is "as many of my
## own as I may". A human seat is held on each question (the resolution
## pre-flight, docs/duel-todo.md §1.3).
##
## - Rewind: one targeted counter and the untargeted untap; a spell that is
##   gone by resolution makes Rewind do nothing at all (CR 608.2b).
## - Time Spiral: exiles itself as it resolves (Recall's flag), every
##   player shuffles hand and graveyard in, then every player draws seven
##   (CR 101.4 order, active player first), then "you" untap up to six.
## - The self-untappers ("{U}: Untap this creature" — Horseshoe Crab,
##   Morphling; Vigilant Drake, Blizzard Elemental, Grim Monolith and
##   Phyrexian Colossus's life-paid one): [method untap_self_ability], which
##   untaps only the very object whose ability it is (CR 400.7) and works
##   while it is summoning sick (no {T} in the cost, CR 302.6).
## - Morphling's shroud is the Giant Crab shape (role `self_bounce`, the
##   fair AI's answer to a spell aimed at it); its flying, Manta Riders'
##   (role `self_keyword`).
## - Back to Basics, Phyrexian Colossus and Grim Monolith set
##   cur_skips_untap (Meekstone / Basalt Monolith shape). Back to Basics
##   reads the LIVE supertype: an Island that is not basic (Tundra, a
##   Lingering Mirage) stays locked. The Colossus's lock works while it is
##   tapped (StaticAbility.working_while_tapped — the 1997 tapped-artifact
##   rule never frees it). Its three-blocker rule is Gorilla Berserkers'.
## - Somnophore: "deals damage to a player" is two triggers with
##   complementary conditions (Soltari Visionary's shape), so the target is
##   a creature of the player it hit. The lock "for as long as this
##   creature remains on the battlefield" starts only if it is still the
##   same object as the trigger resolves, and ends when it leaves or phases
##   out (CR 611.2b, 702.26f — its phase_sequence); it never moves to a new
##   object of the victim (CR 400.7). Not tied to being tapped.
## - Mana Leech: Mole Worms' wording (ice/_permanents.gd Freeze), the lock
##   bound to the land's own object as well; "you may choose not to untap"
##   is the untap step's question, whose hint keeps a Leech that holds a
##   land tapped (memory "holding").
## - Turnabout: both choices are made on resolution — the type
##   (artifact, creature, land), then tap or untap — by its controller;
##   the hint taps an opponent's most numerous untapped type and untaps the
##   caster's most numerous tapped type.
## - Argothian Elder / Voltaic Key: UntapEffect with two (distinct) land
##   targets / one artifact target (an artifact creature is an artifact).
##
## tests/cards/test_pack_10_B9_untap_up_to.gd, test_pack_10_B9_untap.gd and
## test_pack_10_B9_loops.gd (Voltaic Key + Time Vault, Palinchron + High
## Tide, Grim Monolith + Power Artifact) pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_triggers.gd")
const S := preload("res://cards/sets/tmp/_shadow.gd")

const SOMNOPHORE_TEXT := "Whenever this creature deals damage to a player, tap target creature that player controls. That creature doesn't untap during its controller's untap step for as long as this creature remains on the battlefield."

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Back to Basics":
			c.static_ability(StaticAbility.new(_back_to_basics,
				"Nonbasic lands don't untap during their controllers' untap steps."))
		"Great Whale":
			c.triggered(enters_untapping(7, "When this creature enters, untap up to seven lands."))
		"Horseshoe Crab":
			c.activated(untap_self_ability("{U}", "{U}: Untap this creature."))
		"Morphling":
			c.activated(untap_self_ability("{U}", "{U}: Untap this creature."))
			c.activated(ActivatedAbility.new("{U}", false,
				[PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]).self_buff().with_ai_role(&"self_keyword", {"keyword": Mtg.Keyword.FLYING})],
				"{U}: This creature gains flying until end of turn."))
			c.activated(ActivatedAbility.new("{U}", false,
				[F.Action.new(_shroud_self, "this creature gains shroud until end of turn", null, true).with_ai_role(&"self_bounce")],
				"{U}: This creature gains shroud until end of turn."))
			c.activated(ActivatedAbility.new("{1}", false, [PumpEffect.new(1, -1).self_buff()],
				"{1}: This creature gets +1/-1 until end of turn."))
			c.activated(ActivatedAbility.new("{1}", false, [PumpEffect.new(-1, 1).self_buff()],
				"{1}: This creature gets -1/+1 until end of turn."))
		"Peregrine Drake":
			c.triggered(enters_untapping(5, "When this creature enters, untap up to five lands."))
		"Rewind":
			c.spell(CounterEffect.new())
			c.spell(UntapUpToEffect.new(4))
		"Somnophore":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _somnophore, SOMNOPHORE_TEXT,
				S.hits_opponent).targeting(TargetSpec.creature("target creature that player controls")
					.with_source_filter(_theirs), _foe_order,
					"Somnophore: select target creature that player controls to tap."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _somnophore, SOMNOPHORE_TEXT,
				S.hits_controller).targeting(TargetSpec.creature("target creature that player controls")
					.with_source_filter(_yours), _own_order,
					"Somnophore: select target creature that player controls to tap."))
		"Time Spiral":
			c.spell(TimeSpiral.new())
		"Turnabout":
			c.spell(Turnabout.new())
		"Mana Leech":
			c.with_may_skip_untap()
			c.activated(ActivatedAbility.new("", true, [Leech.new()],
				"{T}: Tap target land. It doesn't untap during its controller's untap step for as long as this creature remains tapped."))
		"Argothian Elder":
			var lands := UntapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", F._land))
			lands.target_min = 2
			lands.target_max = 2
			lands.ai_helpful = true
			c.activated(ActivatedAbility.new("", true, [lands], "{T}: Untap two target lands."))
		"Phyrexian Colossus":
			c.static_ability(StaticAbility.new(_skips_untap,
				"This creature doesn't untap during your untap step.").working_while_tapped())
			c.activated(untap_self_ability("", "Pay 8 life: Untap this creature.").with_life_cost(8))
			c.static_ability(StaticAbility.new(_three_blockers,
				"This creature can't be blocked except by three or more creatures."))
		"Voltaic Key":
			var key := UntapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _artifact))
			key.ai_helpful = true
			c.activated(ActivatedAbility.new("{1}", true, [key], "{1}, {T}: Untap target artifact."))
		_: return false
	return true


# ------------------------------------------------- untap up to N lands --

## "When this <permanent> enters, untap up to N lands." — the triggered
## form (Great Whale, Peregrine Drake, Palinchron, Treachery, Cloud of
## Faeries). The trigger resolves even when its source has left (CR 603.6),
## for the seat that controlled it.
static func enters_untapping(n: int, text: String) -> TriggeredAbility:
	return TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD,
		_enters_untap.bind(n), text, F._self_enter)

static func _enters_untap(g: MtgGame, s: CardInstance, _e: GameEvent, n: int) -> void:
	UntapUpToEffect.untap_lands(g, M.pid_of(g, s), n, s)


## "Untap up to N lands." as a spell or ability effect (Rewind, Snap,
## Frantic Search, Time Spiral). Untargeted; [method untap_lands] is the
## same choice for a callback that is not an effect.
class UntapUpToEffect extends EffectBase:
	## The most lands that may be untapped.
	var count: int

	func _init(n: int) -> void:
		count = n
		ai_helpful = true
		# Public shape for the computer's policies: "untaps up to
		# `count` lands" — a mana refund, not removal.
		ai_role = &"untap_lands"
		ai_parameters = {"count": n}

	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		untap_lands(g, pid, count, s)

	func describe() -> String:
		return "untap up to %d lands" % count

	## [param pid] untaps up to [param n] lands of their choice; returns how
	## many became untapped. [param source] names the questions.
	static func untap_lands(g: MtgGame, pid: int, n: int, source: CardInstance = null) -> int:
		if n <= 0 or pid < 0:
			return 0
		var offered := tapped_lands_for(g, pid)
		if offered.is_empty():
			return 0
		var label := source.data.card_name if source != null else "Untap"
		var own := 0
		for land in offered:
			if land.controller_id == pid: own += 1
		var most := mini(n, offered.size())
		var how_many: int = g.agents[pid].choose_number(g, pid, 0, most,
			"%s: untap how many lands? (up to %d)" % [label, n], mini(n, own))
		var chosen: Array[CardInstance] = []
		for _k in clampi(how_many, 0, most):
			if offered.is_empty(): break
			var pick: CardInstance = g.agents[pid].choose_card(g, pid, offered,
				"%s: select a land to untap." % label, false, false, true)
			if pick == null or not offered.has(pick): pick = offered[0]
			offered.erase(pick)
			chosen.append(pick)
		var done := 0
		for land in chosen:
			if g.is_present(land) and land.tapped:
				g.untap_permanent(land)
				done += 1
		return done

	## Every tapped, phased-in land on the battlefield, [param pid]'s own
	## first, each side by the mana one tap of it makes (most first), then
	## in the order they entered. Public information only.
	static func tapped_lands_for(g: MtgGame, pid: int) -> Array[CardInstance]:
		var rows: Array = []
		var order := 0
		for land in g.all_battlefield():
			if land.phased_out or not land.tapped or not land.is_land(): continue
			var yield_now := 0
			for ability in land.cur_mana_abilities:
				yield_now = maxi(yield_now, ability.amount_for(g, land, land.controller_id))
			rows.append([0 if land.controller_id == pid else 1, -yield_now, order, land])
			order += 1
		rows.sort_custom(func(a: Array, b: Array) -> bool:
			for i in 3:
				if a[i] != b[i]: return a[i] < b[i]
			return false)
		var out: Array[CardInstance] = []
		for row in rows: out.append(row[3])
		return out


# ------------------------------------------------------ untap this --

## "{cost}: Untap this creature/artifact." — [param cost] may be "" for a
## cost paid otherwise (the Colossus's 8 life, added by the caller).
static func untap_self_ability(cost: String, text: String, what := "creature") -> ActivatedAbility:
	return ActivatedAbility.new(cost, false,
		[F.Action.new(_untap_self, "untap this %s" % what, null, true)], text)

static func _untap_self(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if F._same_activation_source(g, s):
		g.untap_permanent(s)

## "This creature/artifact doesn't untap during your untap step."
static func _skips_untap(_g: MtgGame, s: CardInstance) -> void:
	s.cur_skips_untap = true


# ------------------------------------------------------- Back to Basics --

static func _back_to_basics(g: MtgGame, _s: CardInstance) -> void:
	for inst in g.all_battlefield():
		if inst.is_land() and (inst.cur_supertypes & Mtg.Supertype.BASIC) == 0:
			inst.cur_skips_untap = true


# ------------------------------------------------------------ Morphling --

static func _shroud_self(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, x: int) -> void:
	if F._same_activation_source(g, s):
		F._grant_shroud(g, s, pid, TargetRef.card(s), x)


# ---------------------------------------------------- Phyrexian Colossus --

static func _three_blockers(_g: MtgGame, s: CardInstance) -> void:
	s.cur_min_blockers = maxi(3, s.cur_min_blockers)


# ----------------------------------------------------------- Voltaic Key --

static func _artifact(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT)


# ------------------------------------------------------------ Somnophore --

## "That player" is the damaged one: an opponent ([method _theirs]) or the
## trigger's own controller ([method _yours]).
static func _theirs(g: MtgGame, s: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id != g.controller_acting_for(s)

static func _yours(g: MtgGame, s: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == g.controller_acting_for(s)

## An opponent's creature: an untapped one first (tapping it costs them
## something), then the biggest.
static func _foe_order(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var x := g.find_instance(a.instance_id)
	var y := g.find_instance(b.instance_id)
	if x.tapped != y.tapped: return not x.tapped
	return x.cur_power + x.cur_toughness > y.cur_power + y.cur_toughness

## One of our own: an already tapped one first, never Somnophore itself
## while another will do, then the smallest.
static func _own_order(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var x := g.find_instance(a.instance_id)
	var y := g.find_instance(b.instance_id)
	if x.tapped != y.tapped: return x.tapped
	if (x == s) != (y == s): return y == s
	return x.cur_power + x.cur_toughness < y.cur_power + y.cur_toughness

## Tap the target; lock it while this same Somnophore stays (CR 611.2b).
## The tap is the trigger's effect and happens even if Somnophore has left.
static func _somnophore(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty():
		return
	var victim := g.find_instance(targets[0].instance_id)
	if not g.is_present(victim):
		return
	g.tap_permanent(victim)
	if not F._same_trigger_source(g, s):
		return   # gone already: the duration ended before it began
	g.continuous.add_floating_static(s, StaticAbility.new(
		_somnophore_lock.bind(victim.id, victim.layer_timestamp, s.layer_timestamp, s.phase_sequence),
		"Doesn't untap during its controller's untap step for as long as Somnophore remains on the battlefield."),
		ContinuousEffects.Duration.INDEFINITE, -1, false, victim.id)
	g.recalculate()

static func _somnophore_lock(g: MtgGame, s: CardInstance, id: int, victim_stamp: int,
		stamp: int, phase: int) -> void:
	if not g.is_present(s) or s.layer_timestamp != stamp or s.phase_sequence != phase:
		return
	var victim := g.find_instance(id)
	if g.is_present(victim) and victim.layer_timestamp == victim_stamp:
		victim.cur_skips_untap = true


# ------------------------------------------------------------ Mana Leech --

class Leech extends TapEffect:
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", F._land))

	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		var land := g.find_instance(t.instance_id)
		# "For as long as this creature remains tapped": only if it still
		# is, since it was activated (CR 611.2b, 702.26f).
		if not g.is_present(land) or not F._remained_tapped(g, s):
			return
		g._rec(s, &"memory")
		s.memory["holding"] = land.id
		g.continuous.add_floating_static(s, StaticAbility.new(
			_lock.bind(land.id, land.layer_timestamp, s.layer_timestamp, s.untap_sequence),
			"Doesn't untap during its controller's untap step for as long as Mana Leech remains tapped."),
			ContinuousEffects.Duration.INDEFINITE, -1, false, land.id)
		g.recalculate()

	func describe() -> String:
		return "tap target land; it doesn't untap while this creature remains tapped"

	static func _lock(g: MtgGame, s: CardInstance, id: int, land_stamp: int, stamp: int,
			untaps: int) -> void:
		if not g.is_present(s) or s.layer_timestamp != stamp or not s.tapped \
				or s.untap_sequence != untaps:
			return
		var land := g.find_instance(id)
		if g.is_present(land) and land.layer_timestamp == land_stamp:
			land.cur_skips_untap = true


# ----------------------------------------------------------- Time Spiral --

class TimeSpiral extends EffectBase:
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		# "Exile Time Spiral." — it never rests in the graveyard.
		g._rec(s, &"exile_after_resolution")
		s.exile_after_resolution = true
		var order: Array[int] = [g.active_player, g.opponent_of(g.active_player)]
		for who in order:
			g.shuffle_hand_and_graveyard_into_library(who)
		for who in order:
			g.draw_cards(who, 7)
		UntapUpToEffect.untap_lands(g, pid, 6, s)

	## Read by the computer's wheel reading (EffectIntent._wheel_draw).
	func describe() -> String:
		return "each player shuffles their hand and graveyard into their library, then draws seven; you untap up to six lands"


# ------------------------------------------------------------- Turnabout --

const TURN_KINDS: Array[int] = [Mtg.CardType.ARTIFACT, Mtg.CardType.CREATURE, Mtg.CardType.LAND]

class Turnabout extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or not t.is_player:
			return
		var who := t.player_id
		var untap_mine := who == pid
		var counts: Array[int] = [0, 0, 0]
		for inst in g.players[who].battlefield:
			if inst.phased_out or inst.tapped != untap_mine: continue
			for k in 3:
				if inst.is_type(TURN_KINDS[k]): counts[k] += 1
		var hint := 2
		for k in [1, 0]:
			if counts[k] > counts[hint]: hint = k
		var kinds: Array[String] = ["Artifact", "Creature", "Land"]
		var kind: int = g.agents[pid].choose_option(g, pid, kinds,
			"Turnabout: choose artifact, creature, or land.", hint)
		var word := ["artifacts", "creatures", "lands"][kind] as String
		var modes: Array[String] = ["Tap all untapped %s that player controls." % word,
			"Untap all tapped %s that player controls." % word]
		var mode: int = g.agents[pid].choose_option(g, pid, modes,
			"Turnabout: tap or untap?", 1 if untap_mine else 0)
		var affected: Array[CardInstance] = []
		for inst in g.players[who].battlefield:
			if not inst.phased_out and inst.is_type(TURN_KINDS[kind]) and inst.tapped == (mode == 1):
				affected.append(inst)
		for inst in affected:
			if mode == 0: g.tap_permanent(inst)
			else: g.untap_permanent(inst)

	func describe() -> String:
		return "tap all untapped, or untap all tapped, artifacts, creatures or lands target player controls"
