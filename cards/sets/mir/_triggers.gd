extends RefCounted
## Mirage (_triggers, Pack 8). Triggered abilities: enters, dies, upkeep, end step and other event triggers.
##
## Conventions every handler here keeps (the 2026-10-03 bug pass's lessons):
## - A triggered ability exists apart from its source (CR 603.6 / 608.2h):
##   it resolves even when the source has left, acting for the seat that
##   controlled it ([method _pid], MtgGame.current_resolution_controller) and
##   dealing damage from the source as it last existed. Only the clauses
##   that name the source itself ("put a counter on it", "sacrifice it")
##   check that the very same object is still there
##   (F._same_trigger_source / F._trigger_source_present).
## - An intervening "if" (CR 603.4) is a condition AND a resolution recheck.
## - Per-occurrence facts (the creature that dealt the damage, the dead
##   card's toughness and graveyard entry) are captured as the ability
##   triggers, never read back later off a permanent that may have changed.
## - "Whenever this creature deals damage" (Zebra Unicorn, Emberwilde
##   Caliph) hears DAMAGE_DEALT once per damage packet, the pool's
##   convention for that wording (4ed/el_hajjaj.gd, 4ed/spirit_link.gd): a
##   trampler's split damage resolves as one trigger per recipient whose
##   amounts add up to what the event dealt.
## The Visions module (cards/sets/vis/_triggers.gd) reuses the shared
## helpers at the bottom of this file.
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Auspicious Ancestor":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _gain_life.bind(3),
				"When this creature dies, you gain 3 life.", F._self_enter))
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _lucky_life,
				"Whenever a player casts a white spell, you may pay {1}. If you do, you gain 1 life.",
				spell_of.bind(Mtg.ManaColor.W)))
		"Mangara's Equity":
			c.as_it_enters(_choose_black_or_red)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._upkeep_payment.bind("{1}{W}"),
				"At the beginning of your upkeep, sacrifice this enchantment unless you pay {1}{W}.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _equity,
				"Whenever a creature of the chosen color deals damage to you or a white creature you control, this enchantment deals that much damage to that creature.",
				_equity_hit).capturing(_damager_context))
		"Sacred Mesa":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _mesa_upkeep,
				"At the beginning of your upkeep, sacrifice this enchantment unless you sacrifice a Pegasus.", F._your_upkeep))
			var pegasus := CreateTokenEffect.new("Pegasus", 1, 1, Mtg.ManaColor.W, "pegasus")
			pegasus.token.with_keywords([Mtg.Keyword.FLYING]).oracle("Flying")
			c.activated(ActivatedAbility.new("{1}{W}", false, [pegasus],
				"{1}{W}: Create a 1/1 white Pegasus creature token with flying."))
		"Wall of Resistance":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _resistance,
				"At the beginning of each end step, if this creature was dealt damage this turn, put a +0/+1 counter on it.",
				_was_damaged))
		"Energy Vortex":
			c.as_it_enters(_choose_vortex_player)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _vortex_clear,
				"At the beginning of your upkeep, remove all vortex counters from this enchantment.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _vortex_bill,
				"At the beginning of the chosen player's upkeep, this enchantment deals 3 damage to that player unless they pay {1} for each vortex counter on this enchantment.",
				_vortex_upkeep).capturing(_counters_context))
			c.activated(ActivatedAbility.new("{X}", false,
				[F.Action.new(_vortex_feed, "put X vortex counters on this enchantment", null, true)],
				"{X}: Put X vortex counters on this enchantment. Activate only during your upkeep.")
				.during_step(Mtg.Step.UPKEEP).your_turn_only())
		"Floodgate":
			c.triggered(TriggeredAbility.new(Mtg.EventType.STATE_CHECK, sacrifice_source,
				"When this creature has flying, sacrifice it.", _has_flying))
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _floodgate_wave,
				"When this creature leaves the battlefield, it deals damage to each nonblue creature without flying equal to half the number of Islands you control, rounded down.",
				F._self_enter))
		"Merfolk Seer":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _seer,
				"When this creature dies, you may pay {1}{U}. If you do, draw a card.", F._self_enter))
		"Harbinger of Night":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _harbinger,
				"At the beginning of your upkeep, put a -1/-1 counter on each creature.", F._your_upkeep))
		"Purraj of Urborg":
			c.static_ability(StaticAbility.new(_purraj_strike,
				"Purraj has first strike as long as it's attacking.").changing_abilities())
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _purraj_counter,
				"Whenever a player casts a black spell, you may pay {B}. If you do, put a +1/+1 counter on Purraj.",
				spell_of.bind(Mtg.ManaColor.B)))
		"Ravenous Vampire":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _vampire,
				"At the beginning of your upkeep, you may sacrifice a nonartifact creature. If you do, put a +1/+1 counter on this creature. If you don't, tap this creature.",
				F._your_upkeep))
		"Shauku, Endbringer":
			c.static_ability(StaticAbility.new(_shauku_alone,
				"Shauku can't attack if there's another creature on the battlefield."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, lose_life.bind(3),
				"At the beginning of your upkeep, you lose 3 life.", F._your_upkeep))
			c.activated(ActivatedAbility.new("", true,
				[ExileEffect.new(TargetSpec.creature()), F.Action.new(_shauku_counter, "put a +1/+1 counter on Shauku", null, true)],
				"{T}: Exile target creature and put a +1/+1 counter on Shauku."))
		"Zombie Mob":
			c.as_it_enters(_mob_counters)
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _mob_exile,
				"When this creature enters, exile all creature cards from your graveyard.", F._self_enter))
		"Emberwilde Djinn":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _emberwilde,
				"At the beginning of each player's upkeep, that player may pay {R}{R} or 2 life. If the player does, they gain control of this creature."))
		"Afiya Grove":
			c.with_enters_counters("+1/+1", 3)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _afiya_move,
				"At the beginning of your upkeep, move a +1/+1 counter from this enchantment onto target creature.",
				F._your_upkeep).targeting(TargetSpec.creature(), friendly_first,
				"Move a +1/+1 counter from Afiya Grove onto target creature."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.STATE_CHECK, sacrifice_source,
				"When this enchantment has no +1/+1 counters on it, sacrifice it.", _no_plus_counters))
		"Nettletooth Djinn":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, self_damage.bind(1),
				"At the beginning of your upkeep, this creature deals 1 damage to you.", F._your_upkeep))
		"Preferred Selection":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _preferred,
				"At the beginning of your upkeep, look at the top two cards of your library. You may sacrifice this enchantment and pay {2}{G}{G}. If you do, put one of those cards into your hand. If you don't, put one of those cards on the bottom of your library.",
				F._your_upkeep))
		"Roots of Life":
			c.as_it_enters(_choose_island_or_swamp)
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TAPPED, _gain_life.bind(1),
				"Whenever a land of the chosen type an opponent controls becomes tapped, you gain 1 life.", _roots_tapped))
		"Benthic Djinn":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, lose_life.bind(2),
				"At the beginning of your upkeep, you lose 2 life.", F._your_upkeep))
		"Discordant Spirit":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _discordant_grow,
				"At the beginning of each end step, if it's an opponent's turn, put a +1/+1 counter on this creature for each 1 damage dealt to you this turn.",
				_opponents_turn))
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _discordant_shed,
				"At the beginning of your end step, remove all +1/+1 counters from this creature.", F._your_upkeep))
		"Emberwilde Caliph":
			c.with_keywords([Mtg.Keyword.MUST_ATTACK])
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _caliph,
				"Whenever this creature deals damage, you lose that much life.", deals_damage))
		"Grim Feast":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, self_damage.bind(1),
				"At the beginning of your upkeep, this enchantment deals 1 damage to you.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _feast,
				"Whenever a creature is put into an opponent's graveyard from the battlefield, you gain life equal to its toughness.",
				_opponent_creature_died).capturing(_dead_context))
		"Purgatory":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _purgatory_exile,
				"Whenever a nontoken creature is put into your graveyard from the battlefield, exile that card.",
				_own_nontoken_creature_died).capturing(_dead_context))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _purgatory_return,
				"At the beginning of your upkeep, you may pay {4} and 2 life. If you do, return a card exiled with this enchantment to the battlefield.",
				F._your_upkeep).capturing(_purgatory_context))
		"Reparations":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _reparations,
				"Whenever an opponent casts a spell that targets you or a creature you control, you may draw a card.",
				_targets_you_or_yours))
		"Zebra Unicorn":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _zebra,
				"Whenever this creature deals damage, you gain that much life.", deals_damage))
		"Phyrexian Dreadnought":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _dreadnought,
				"When this creature enters, sacrifice it unless you sacrifice any number of creatures with total power 12 or greater.",
				F._self_enter))
		"Sand Golem":
			c.triggers_when_discarded(_golem_discarded)
		"Skulking Ghost":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, sacrifice_source,
				"When this creature becomes the target of a spell or ability, sacrifice it.", targeted_me))
		"Asmira, Holy Avenger":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _asmira,
				"At the beginning of each end step, put a +1/+1 counter on Asmira for each creature put into your graveyard from the battlefield this turn."))
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

## The seat the resolving ability acts for — "you" on its card (CR 603.3a:
## the controller of the source when it triggered; for a departed source
## that is its LAST controller, not its owner it has gone home to).
static func pid_of(g: MtgGame, s: CardInstance) -> int:
	var pid := g.current_resolution_controller()
	return pid if pid >= 0 else s.controller_id

static func spell_of(_g: MtgGame, _s: CardInstance, e: GameEvent, color: int) -> bool:
	var spell: CardInstance = e.data.get("instance")
	return spell != null and (spell.cur_colors & color) != 0

static func deals_damage(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("source") == s and int(e.data.get("amount", 0)) > 0

## "Sacrifice it" — only the same object, and only by the player who still
## controls it (CR 701.17a: you sacrifice only what you control).
static func sacrifice_source(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._trigger_source_present(g, s) and s.controller_id == pid_of(g, s):
		g.sacrifice_permanent(s)

## "When this creature becomes the target of a spell or ability" — the
## engine's BECAME_TARGET is announced once per distinct target per stack
## object (CR 601.2c, 602.2b, 603.3d, 707.10c), so a spell naming this
## creature in two of its target slots still triggers it once.
static func targeted_me(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s

static func _gain_life(g: MtgGame, s: CardInstance, _e: GameEvent, amount: int) -> void:
	g.adjust_life(pid_of(g, s), amount)

static func lose_life(g: MtgGame, s: CardInstance, _e: GameEvent, amount: int) -> void:
	g.adjust_life(pid_of(g, s), -amount)

## "This permanent deals N damage to you" — from the source as it last
## existed if it has left (Juzám Djinn's pattern, arn/juzam_djinn.gd).
static func self_damage(g: MtgGame, s: CardInstance, _e: GameEvent, amount: int) -> void:
	g.deal_damage(s, TargetRef.player(pid_of(g, s)), amount)

## A targeted trigger's preference for a HELPFUL target: the acting seat's
## own creatures first, the biggest first.
static func friendly_first(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var me := g.controller_acting_for(s)
	var ai := g.find_instance(a.instance_id)
	var bi := g.find_instance(b.instance_id)
	if ai == null or bi == null: return ai != null
	var av := (1000 if ai.controller_id == me else 0) + ai.cur_power + ai.cur_toughness
	var bv := (1000 if bi.controller_id == me else 0) + bi.cur_power + bi.cur_toughness
	return av > bv

static func creatures_of(g: MtgGame, pid: int, filter := Callable()) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_creature() and (not filter.is_valid() or filter.call(i)):
			out.append(i)
	return out

## Cheapest-to-lose first: tokens, then the smallest bodies. The order a
## heuristic seat answers "return / sacrifice a creature you control" in.
static func least_valuable_first(list: Array[CardInstance], keep: CardInstance = null) -> void:
	list.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		if (a == keep) != (b == keep): return b == keep
		if a.is_token != b.is_token: return a.is_token
		return a.cur_power + a.cur_toughness + a.data.cost.mana_value() \
			< b.cur_power + b.cur_toughness + b.data.cost.mana_value())

## Capture what one occurrence of a "dies" trigger needs (CR 603.10: look
## back in time): the dead card's graveyard entry and last toughness.
static func _dead_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var dead: CardInstance = e.data.get("instance")
	ctx["id"] = dead.id
	ctx["entry"] = int(e.data.get("graveyard_entry", dead.graveyard_entry))
	ctx["toughness"] = dead.last_toughness
	return ctx

## Pick one of [param candidates] for [param pid]; a null or foreign answer
## becomes the first candidate (the funnel's non-optional contract).
## [param ranked]: the callers hand the list RANKED for the seat, best
## answer first — "least valuable first" for what it loses (the creature a
## Wildebeests returns, the card Preferred Selection buries) — so the ask
## is ORDERED ([member PlayerChoice.ordered]) and a heuristic seat takes
## the first instead of the most valuable card, which for a loss worded
## without a tribute word ("return", "bottom") was the worst answer.
## False for a list in no particular order (Goblin Recruiter's goblins).
static func pick(g: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String,
		ranked := true) -> CardInstance:
	var chosen := g.agents[pid].choose_card(g, pid, candidates, prompt, false, false, ranked)
	return chosen if chosen != null and candidates.has(chosen) else candidates[0]


# ------------------------------------------------------- Auspicious Ancestor --

static func _lucky_life(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := pid_of(g, s)
	if EffectBase.unless_paid(g, pid, ManaCost.parse("{1}"), "Pay {1} for Auspicious Ancestor to gain 1 life?", true):
		g.adjust_life(pid, 1)


# ---------------------------------------------------------- Mangara's Equity --

## "As this enters, choose black or red" — a replacement (CR 614.12), so the
## colour is set before any damage could be dealt. The heuristic answer is
## the colour the opponents field more creatures of (public board only).
static func _choose_black_or_red(g: MtgGame, inst: CardInstance, controller: int) -> void:
	var black := 0
	var red := 0
	for i in g.all_battlefield():
		if i.controller_id != controller and i.is_creature():
			if i.has_color(Mtg.ManaColor.B): black += 1
			if i.has_color(Mtg.ManaColor.R): red += 1
	var options: Array[String] = ["Black", "Red"]
	var pick := g.agents[controller].choose_option(g, controller, options,
		"Mangara's Equity: choose black or red", 1 if red > black else 0)
	g._rec(inst, &"memory")
	inst.memory["chosen_color"] = Mtg.ManaColor.R if pick == 1 else Mtg.ManaColor.B
	g.log_line("Mangara's Equity: %s chooses %s" % [g.players[controller].player_name, options[pick].to_lower()])

static func _equity_hit(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var from: CardInstance = e.data.get("source") as CardInstance
	var color := int(s.memory.get("chosen_color", 0))
	if from == null or color == 0 or not from.is_creature() or (from.cur_colors & color) == 0:
		return false
	if e.data.has("to_player"):
		return int(e.data.to_player) == s.controller_id
	var hit: CardInstance = e.data.get("to_instance")
	return hit != null and hit.is_creature() and hit.controller_id == s.controller_id \
		and hit.has_color(Mtg.ManaColor.W)

static func _damager_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var from: CardInstance = e.data.get("source")
	ctx["damager"] = from.id
	ctx["damager_stamp"] = from.layer_timestamp
	ctx["amount"] = int(e.data.get("amount", 0))
	return ctx

## "That much damage to that creature" — the creature that dealt it, if it
## is still the same object; from the Equity as it last existed if it left.
static func _equity(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var creature := g.find_instance(int(ctx.get("damager", -1)))
	var amount := int(ctx.get("amount", 0))
	if creature != null and creature.zone == Mtg.Zone.BATTLEFIELD \
			and creature.layer_timestamp == int(ctx.get("damager_stamp", -1)) and amount > 0:
		g.deal_damage(s, TargetRef.card(creature), amount)


# --------------------------------------------------------------- Sacred Mesa --

static func _mesa_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := pid_of(g, s)
	if not F._trigger_source_present(g, s) or s.controller_id != pid:
		return   # nothing left to keep: the "unless" offers nothing
	var pegasi: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.has_subtype("pegasus"): pegasi.append(i)
	least_valuable_first(pegasi)
	if not pegasi.is_empty() and g.agents[pid].choose_yes_no(g, pid, "Sacrifice a Pegasus to keep Sacred Mesa?", true):
		g.sacrifice_permanent(pick(g, pid, pegasi, "Sacrifice a Pegasus"))
		return
	g.sacrifice_permanent(s)


# -------------------------------------------------------- Wall of Resistance --

## Intervening "if" (CR 603.4): checked as the end step begins and again on
## resolution.
static func _was_damaged(_g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	return not s.damaged_by_this_turn.is_empty()

static func _resistance(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	if F._same_trigger_source(g, s) and _was_damaged(g, s, e):
		g.add_counters(s, "+0/+1")


# ------------------------------------------------------------- Energy Vortex --

## "As this enters, choose an opponent" (CR 614.12).
static func _choose_vortex_player(g: MtgGame, inst: CardInstance, controller: int) -> void:
	var who := g.choose_opponent(controller, inst)
	g._rec(inst, &"memory")
	inst.memory["chosen_player"] = who
	g.log_line("Energy Vortex: %s chooses %s" % [g.players[controller].player_name, g.players[who].player_name])

static func _vortex_upkeep(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("player", -1)) == int(s.memory.get("chosen_player", -2))

static func _counters_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	ctx["who"] = int(e.data.get("player", -1))
	return ctx

static func _vortex_clear(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s):
		g.remove_counters(s, "vortex", int(s.counters.get("vortex", 0)))

## The bill counts the vortex counters as the ability resolves — on the
## Vortex as it last existed if it has left (CR 608.2h). With none, the
## price is {0}, which every player pays.
static func _vortex_bill(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := int(g.trigger_context(s).get("who", -1))
	if who < 0: return
	var counters: Dictionary = s.counters if F._same_trigger_object(g, s) else s.last_counters
	var n := int(counters.get("vortex", 0))
	if n <= 0:
		g.log_line("Energy Vortex: %s pays {0}" % g.players[who].player_name)
		return
	if EffectBase.unless_paid(g, who, ManaCost.parse("{%d}" % n),
			"Pay {%d} to prevent Energy Vortex's 3 damage?" % n, true):
		return
	g.deal_damage(s, TargetRef.player(who), 3)

static func _vortex_feed(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, x: int) -> void:
	if x > 0 and F._same_activation_source(g, s):
		g.add_counters(s, "vortex", x)


# ----------------------------------------------------------------- Floodgate --

## A STATE trigger (CR 603.8): it triggers once whenever the creature has
## flying and not again until it has resolved (MtgGame._check_state_triggers).
static func _has_flying(_g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	return s.has_keyword(Mtg.Keyword.FLYING)

static func _floodgate_wave(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := pid_of(g, s)
	var islands := 0
	for i in g.players[pid].battlefield:
		if i.is_land() and i.has_subtype("island"): islands += 1
	var amount := floori(islands / 2.0)
	if amount <= 0: return
	var victims: Array[CardInstance] = []
	for i in g.all_battlefield():
		if i.is_creature() and not i.has_color(Mtg.ManaColor.U) and not i.has_keyword(Mtg.Keyword.FLYING):
			victims.append(i)
	g.begin_simultaneous()
	for i in victims:
		g.deal_damage(s, TargetRef.card(i), amount)
	g.end_simultaneous()


# -------------------------------------------------------------- Merfolk Seer --

static func _seer(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := pid_of(g, s)
	if EffectBase.unless_paid(g, pid, ManaCost.parse("{1}{U}"), "Pay {1}{U} to draw a card (Merfolk Seer)?", true):
		g.draw_cards(pid, 1)


# -------------------------------------------------------- Harbinger of Night --

static func _harbinger(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var all: Array[CardInstance] = []
	for i in g.all_battlefield():
		if i.is_creature(): all.append(i)
	g.begin_simultaneous()
	for i in all:
		g.add_counters(i, "-1/-1")
	g.end_simultaneous()


# ---------------------------------------------------------- Purraj of Urborg --

static func _purraj_strike(g: MtgGame, s: CardInstance) -> void:
	if g.combat.attackers.has(s.id) and not s.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE):
		s.cur_keywords.append(Mtg.Keyword.FIRST_STRIKE)

static func _purraj_counter(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	# "If you do, put a +1/+1 counter on Purraj": with Purraj gone there is
	# nothing to pay for, so the offer is not made.
	if not F._same_trigger_source(g, s): return
	if EffectBase.unless_paid(g, pid_of(g, s), ManaCost.parse("{B}"), "Pay {B} to put a +1/+1 counter on Purraj?", true):
		g.add_counters(s, "+1/+1")


# ---------------------------------------------------------- Ravenous Vampire --

static func _vampire(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := pid_of(g, s)
	var food := creatures_of(g, pid, func(i: CardInstance) -> bool: return not i.is_type(Mtg.CardType.ARTIFACT))
	least_valuable_first(food, s)
	var cheap := not food.is_empty() and food[0] != s \
		and (food[0].is_token or food[0].cur_power + food[0].cur_toughness <= 2)
	if not food.is_empty() and g.agents[pid].choose_yes_no(g, pid,
			"Sacrifice a nonartifact creature to put a +1/+1 counter on Ravenous Vampire? (Otherwise it becomes tapped.)", cheap):
		g.sacrifice_permanent(pick(g, pid, food, "Sacrifice a nonartifact creature"))
		g.add_counters(s, "+1/+1")
	else:
		g.tap_permanent(s)


# --------------------------------------------------------- Shauku, Endbringer --

static func _shauku_alone(g: MtgGame, s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i != s and i.is_creature():
			s.cur_cant_attack = true
			return

static func _shauku_counter(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if F._same_activation_source(g, s):
		g.add_counters(s, "+1/+1")


# ---------------------------------------------------------------- Zombie Mob --

## "Enters with a +1/+1 counter for each creature card in your graveyard" —
## counted as it enters, before the exile trigger empties the graveyard.
static func _mob_counters(g: MtgGame, inst: CardInstance, controller: int) -> void:
	var n := 0
	for card in g.players[controller].graveyard:
		if card.data.is_creature(): n += 1
	if n > 0:
		g.add_counters(inst, "+1/+1", n)

static func _mob_exile(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := pid_of(g, s)
	for card in g.players[pid].graveyard.duplicate():
		if card.data.is_creature():
			g.exile_from_graveyard(card)


# ---------------------------------------------------------- Emberwilde Djinn --

## The UPKEEP player's choice ("that player may pay"), not the Djinn's
## controller's. Paying life needs that much life (CR 119.4).
static func _emberwilde(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var who := int(e.data.get("player", -1))
	if who < 0: return
	var rr := ManaCost.parse("{R}{R}")
	var options: Array[String] = []
	var kinds: Array[String] = []
	if g.can_afford_cost(who, rr):
		options.append("Pay {R}{R}")
		kinds.append("mana")
	if g.players[who].life >= 2:
		options.append("Pay 2 life")
		kinds.append("life")
	options.append("Don't pay")
	kinds.append("none")
	var hint := kinds.size() - 1
	if s.controller_id != who:
		if kinds.has("mana"): hint = kinds.find("mana")
		elif kinds.has("life") and g.players[who].life > 6: hint = kinds.find("life")
	var choice := g.agents[who].choose_option(g, who, options,
		"Emberwilde Djinn: pay {R}{R} or 2 life to gain control of it?", hint)
	match kinds[clampi(choice, 0, kinds.size() - 1)]:
		"mana":
			if not g.try_pay(who, rr): return
		"life":
			g.adjust_life(who, -2)
		_:
			return
	if F._same_trigger_source(g, s) and s.controller_id != who:
		g.change_control(s, who)


# --------------------------------------------------------------- Afiya Grove --

static func _no_plus_counters(_g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	return int(s.counters.get("+1/+1", 0)) <= 0

## "Move a +1/+1 counter from this enchantment": with the Grove gone (or
## out of counters) there is nothing to move (CR 122.5).
static func _afiya_move(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty() or not F._same_trigger_source(g, s) or int(s.counters.get("+1/+1", 0)) <= 0:
		return
	var creature := g.find_instance((targets[0] as TargetRef).instance_id)
	if creature == null or creature.zone != Mtg.Zone.BATTLEFIELD: return
	g.remove_counters(s, "+1/+1", 1)
	g.add_counters(creature, "+1/+1", 1)


# ------------------------------------------------------- Preferred Selection --

## Rank looked-at cards best-first for [param pid]: a land while it is short
## of lands, otherwise what it can soon cast. Only the two looked-at cards
## and the public board are read (fair information).
static func _rank_looked(g: MtgGame, pid: int, cards: Array[CardInstance]) -> void:
	var lands := 0
	for i in g.players[pid].battlefield:
		if i.is_land(): lands += 1
	cards.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return _keep_score(a, lands) > _keep_score(b, lands))

static func _keep_score(card: CardInstance, lands: int) -> int:
	if card.data.is_land():
		return 10 if lands < 5 else 1
	var mv := card.data.cost.mana_value()
	return 8 - absi(mv - lands - 1) if mv <= lands + 2 else 2

static func _preferred(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := pid_of(g, s)
	var library := g.players[pid].library
	if library.is_empty(): return
	var looked: Array[CardInstance] = []
	for n in mini(2, library.size()):
		looked.append(library[library.size() - 1 - n])   # the top is the array's end
	var names: Array = []
	for card in looked: names.append(card.data.card_name)
	g.reveal_information(pid, "Preferred Selection — the top of your library", names)
	_rank_looked(g, pid, looked)
	var cost := ManaCost.parse("{2}{G}{G}")
	var paid := false
	if F._trigger_source_present(g, s) and s.controller_id == pid and g.can_afford_cost(pid, cost) \
			and g.agents[pid].choose_yes_no(g, pid,
				"Sacrifice Preferred Selection and pay {2}{G}{G} to put one of those cards into your hand?", false):
		paid = g.try_pay(pid, cost)
		if paid: g.sacrifice_permanent(s)
	if paid:
		g.library_card_to_hand(pick(g, pid, looked, "Put one of those cards into your hand"))
	else:
		looked.reverse()   # worst first: the heuristic buries the weaker card
		g.put_on_bottom_of_library(pick(g, pid, looked, "Put one of those cards on the bottom of your library"))


# ------------------------------------------------------------- Roots of Life --

static func _choose_island_or_swamp(g: MtgGame, inst: CardInstance, controller: int) -> void:
	var islands := 0
	var swamps := 0
	for i in g.all_battlefield():
		if i.controller_id != controller and i.is_land():
			if i.has_subtype("island"): islands += 1
			if i.has_subtype("swamp"): swamps += 1
	var options: Array[String] = ["Island", "Swamp"]
	var choice := g.agents[controller].choose_option(g, controller, options,
		"Roots of Life: choose Island or Swamp", 1 if swamps > islands else 0)
	g._rec(inst, &"memory")
	inst.memory["land_type"] = "swamp" if choice == 1 else "island"
	g.log_line("Roots of Life: %s chooses %s" % [g.players[controller].player_name, options[choice]])

static func _roots_tapped(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var land: CardInstance = e.data.get("instance")
	var kind := String(s.memory.get("land_type", ""))
	return land != null and kind != "" and land.is_land() and land.has_subtype(kind) \
		and int(e.data.get("controller", land.controller_id)) != s.controller_id


# --------------------------------------------------------- Discordant Spirit --

## Intervening "if" (CR 603.4): "if it's an opponent's turn" — of the
## trigger's controller, rechecked on resolution.
static func _opponents_turn(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	return g.active_player != s.controller_id

static func _discordant_grow(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := pid_of(g, s)
	if g.active_player == pid or not F._same_trigger_source(g, s): return
	var n := g.players[pid].damage_taken_this_turn
	if n > 0:
		g.add_counters(s, "+1/+1", n)

static func _discordant_shed(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s):
		g.remove_counters(s, "+1/+1", int(s.counters.get("+1/+1", 0)))


# --------------------------------------------- Emberwilde Caliph, Zebra Unicorn --

static func _caliph(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	g.adjust_life(pid_of(g, s), -int(e.data.get("amount", 0)))

static func _zebra(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	g.adjust_life(pid_of(g, s), int(e.data.get("amount", 0)))


# ---------------------------------------------------------------- Grim Feast --

## "Put into an opponent's graveyard": a card goes to its OWNER's graveyard,
## so the dead creature's owner must be an opponent (a token, too: it
## reaches the graveyard before it ceases to exist, CR 111.7).
static func _opponent_creature_died(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and (dead.last_types & Mtg.CardType.CREATURE) != 0 and dead.owner_id != s.controller_id

static func _feast(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var toughness := int(g.trigger_context(s).get("toughness", 0))
	if toughness > 0:
		g.adjust_life(pid_of(g, s), toughness)


# ----------------------------------------------------------------- Purgatory --

static func _own_nontoken_creature_died(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and not dead.is_token and (dead.last_types & Mtg.CardType.CREATURE) != 0 \
		and dead.owner_id == s.controller_id

## "Exile that card" — the card that hit the graveyard, if it is still that
## object (CR 400.7). It is linked to this Purgatory (CR 607.2a) only while
## this Purgatory is the object that triggered.
static func _purgatory_exile(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var card := g.find_instance(int(ctx.get("id", -1)))
	if card == null or card.zone != Mtg.Zone.GRAVEYARD or card.graveyard_entry != int(ctx.get("entry", -1)):
		return
	g.exile_from_graveyard(card)
	if card.zone == Mtg.Zone.EXILE and F._same_trigger_source(g, s):
		g._rec(s, &"memory")
		var linked: Array = s.memory.get("purgatory_exiled", [])
		linked.append([card.id, card.exile_entry])
		s.memory["purgatory_exiled"] = linked

static func _purgatory_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	ctx["exiled"] = (s.memory.get("purgatory_exiled", []) as Array).duplicate(true)
	return ctx

static func _purgatory_return(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := pid_of(g, s)
	var candidates: Array[CardInstance] = []
	for row in g.trigger_context(s).get("exiled", []):
		var card := g.find_instance(int(row[0]))
		if card != null and card.zone == Mtg.Zone.EXILE and card.exile_entry == int(row[1]):
			candidates.append(card)
	var cost := ManaCost.parse("{4}")
	if candidates.is_empty() or g.players[pid].life < 2 or not g.can_afford_cost(pid, cost):
		return
	candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return a.data.power + a.data.toughness > b.data.power + b.data.toughness)
	if not g.agents[pid].choose_yes_no(g, pid, "Pay {4} and 2 life to return a card exiled with Purgatory to the battlefield?",
			g.players[pid].life > 8):
		return
	if not g.try_pay(pid, cost): return
	g.adjust_life(pid, -2)
	var card := pick(g, pid, candidates, "Return a card exiled with Purgatory to the battlefield")
	g.return_from_exile_to_play(card, card.owner_id)
	if F._same_trigger_source(g, s):
		g._rec(s, &"memory")
		var linked: Array = s.memory.get("purgatory_exiled", [])
		s.memory["purgatory_exiled"] = linked.filter(func(row: Array) -> bool: return int(row[0]) != card.id)


# --------------------------------------------------------------- Reparations --

## Read from the spell's stack object as it is cast — its targets are
## locked by then (CR 601.2c, 601.2i).
static func _targets_you_or_yours(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	if int(e.data.get("controller", s.controller_id)) == s.controller_id: return false
	var spell: CardInstance = e.data.get("instance")
	var item := g.find_stack_item(spell) if spell != null else null
	if item == null: return false
	for ref in item.targets:
		if ref.is_player:
			if ref.player_id == s.controller_id: return true
		else:
			var inst := g.find_instance(ref.instance_id)
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD and inst.is_creature() \
					and inst.controller_id == s.controller_id:
				return true
	return false

static func _reparations(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := pid_of(g, s)
	if g.agents[pid].choose_yes_no(g, pid, "Draw a card (Reparations)?", not g.players[pid].library.is_empty()):
		g.draw_cards(pid, 1)


# ----------------------------------------------------- Phyrexian Dreadnought --

## The sacrifice is a choice made on resolution: any set of OTHER creatures
## whose total power reaches 12 (sacrificing the Dreadnought to itself would
## change nothing). They go together, simultaneously.
static func _dreadnought(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := pid_of(g, s)
	if not F._trigger_source_present(g, s) or s.controller_id != pid: return
	var pool := creatures_of(g, pid, func(i: CardInstance) -> bool: return i != s)
	pool.sort_custom(func(a: CardInstance, b: CardInstance) -> bool: return a.cur_power > b.cur_power)
	var reachable := 0
	var greedy := 0
	for i in pool:
		if i.cur_power > 0:
			if reachable < 12: greedy += 1
			reachable += i.cur_power
	if reachable >= 12 and g.agents[pid].choose_yes_no(g, pid,
			"Sacrifice creatures with total power 12 or greater to keep Phyrexian Dreadnought?",
			greedy <= 2 and (not s.is_token or _dreadnought_token_lethal(g, s, pid))):
		var picked: Array[CardInstance] = []
		var power := 0
		while power < 12 and not pool.is_empty():
			var one := pick(g, pid, pool, "Sacrifice creatures with total power 12 or greater (%d so far)" % power)
			picked.append(one)
			pool.erase(one)
			power += one.cur_power
		if power >= 12:
			g.begin_simultaneous()
			for i in picked: g.sacrifice_permanent(i)
			g.end_simultaneous()
			return
	g.sacrifice_permanent(s)


## The hint for a TOKEN Dreadnought (campaign 2026-10, w3-6): a token copy
## is a one-turn body (Echo Chamber exiles it at the next end step), so it
## is worth the creatures only when it swings for lethal THIS turn — its
## controller's turn before attackers are declared, able to attack, and its
## power (less every untapped enemy body's toughness for a trampler, all of
## it only past no blocker at all) reaching the opponent's life. Public
## board only.
static func _dreadnought_token_lethal(g: MtgGame, s: CardInstance, pid: int) -> bool:
	if g.active_player != pid or g.current_step() not in [Mtg.Step.UPKEEP, Mtg.Step.DRAW,
			Mtg.Step.MAIN1, Mtg.Step.COMBAT_BEGIN]:
		return false
	if s.summoning_sick and not s.has_keyword(Mtg.Keyword.HASTE):
		return false
	var foe := g.opponent_of(pid)
	var soak := 0
	var blockers := 0
	for i in g.players[foe].battlefield:
		if i.is_creature() and not i.tapped and g.is_present(i):
			blockers += 1
			soak += maxi(i.cur_toughness - i.damage, 0)
	var through := s.cur_power - soak if s.has_keyword(Mtg.Keyword.TRAMPLE) \
		else (s.cur_power if blockers == 0 else 0)
	return through >= g.players[foe].life


# ---------------------------------------------------------------- Sand Golem --

## "When a spell or ability an opponent controls causes you to discard this
## card" — the discard hook (CardData.on_discarded) puts the trigger on the
## stack (CR 603.2); it resolves into the delayed "at the beginning of the
## next end step" return (CR 603.7), which checks the card is still that
## graveyard object (CR 400.7).
static func _golem_discarded(g: MtgGame, inst: CardInstance, pid: int, cause_pid: int) -> void:
	if cause_pid < 0 or cause_pid == pid: return
	var trigger := TriggeredAbility.new(Mtg.EventType.CARD_DISCARDED,
		_golem_delay.bind(inst.graveyard_entry, inst.zone == Mtg.Zone.GRAVEYARD),
		"Return Sand Golem from your graveyard to the battlefield with a +1/+1 counter on it at the beginning of the next end step.")
	g.queue_reflexive_trigger(trigger, pid, inst,
		GameEvent.new(Mtg.EventType.CARD_DISCARDED, {"player": pid, "instance": inst}))

static func _golem_delay(g: MtgGame, s: CardInstance, _e: GameEvent, entry: int, in_graveyard: bool) -> void:
	if not in_graveyard: return   # discarded somewhere else (Library of Leng)
	var pid := pid_of(g, s)
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _golem_return.bind(entry, pid),
		"Return Sand Golem from your graveyard to the battlefield with a +1/+1 counter on it."), pid, s)

static func _golem_return(g: MtgGame, s: CardInstance, _e: GameEvent, entry: int, pid: int) -> void:
	if s.zone != Mtg.Zone.GRAVEYARD or s.graveyard_entry != entry: return
	g.reanimate(s, pid)
	if s.zone == Mtg.Zone.BATTLEFIELD:
		g.add_counters(s, "+1/+1")


# ------------------------------------------------------ Asmira, Holy Avenger --

## Counted as the ability resolves — "this turn" includes a creature that
## died with the trigger waiting. "Your graveyard" is the graveyard of the
## player the ability acts for (the tracker is owner-keyed, E10).
static func _asmira(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var n := g.players[pid_of(g, s)].creatures_to_graveyard_this_turn
	if n > 0:
		g.add_counters(s, "+1/+1", n)
