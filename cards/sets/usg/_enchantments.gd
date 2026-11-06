extends RefCounted
## Urza's Saga (_enchantments, Pack 10). Non-Aura enchantments: global statics, triggers and activations.
##
## - The verse-counter cycle (Serra's Liturgy, Lilting Refrain, Recantation,
##   Discordant Dirge, Vile Requiem, Rumbling Crescendo, Torch Song,
##   Midsummer Revel, War Dance; Serra's Hymn is a one-off): "you may put a
##   verse counter" is asked at each of its controller's upkeeps. An
##   "up to X targets" count is fixed as the ability is announced, while the
##   counters are still on the enchantment (CR 601.2c comes before the
##   sacrifice cost, 601.2h — Pack 9 E7's target_count_fn); every other X
##   is the count the sacrifice recorded with the cost (`_source_counters`,
##   CR 608.2h), so counters added in response change nothing.
## - Diabolic Servitude links the creature it returned to THIS object by id
##   and battlefield timestamp (CR 400.7, 607.2a); the leave trigger reads
##   the link from the departing memory snapshot.
## - No Rest for the Wicked reads MtgGame.deaths_this_turn: a creature card
##   in your graveyard that died this turn, on the same graveyard visit.
## - Sneak Attack: the haste is permanent (no duration, CR 611.2), the
##   sacrifice is a delayed end-step sacrifice by the activating player,
##   who must still control the creature (CR 603.7d, 701.17a).
## - Sulfuric Vapors: a damage modifier (+1) on every red SPELL's damage,
##   the color read live as the damage would be dealt (CR 609.7b), once
##   per damage event and victim.
## - Abundance replaces each of its controller's draws (CR 614.1a) with one
##   question: draw, or reveal until a land / a nonland card. The revealed
##   rest go to the bottom in the order the player chooses; an empty
##   library reveals nothing and draws nothing (no loss, CR 121.4). The draw
##   STEP's draw is a turn-based action: Pack 10 E11 holds its question for
##   a human seat (MtgGame._hold_draw_step), so every question here goes
##   through the seat's own funnel.
## - Worship works only while its controller controls a creature, and only
##   against damage (life loss still kills).
## - Greener Pastures: an intervening "if" (CR 603.4), checked as it
##   triggers and again on resolution.
## tests/cards/test_pack_10_B6_*.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const MC := preload("res://cards/sets/mir/_combat.gd")

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G
const ETB := Mtg.EventType.ENTERS_BATTLEFIELD
const LEAVES := Mtg.EventType.LEAVES_BATTLEFIELD
const DIES := Mtg.EventType.DIES
const UPKEEP := Mtg.EventType.UPKEEP_START
const CAST := Mtg.EventType.SPELL_CAST
const VERSE_LINE := "At the beginning of your upkeep, you may put a verse counter on this enchantment."


static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Absolute Grace":
			c.static_ability(StaticAbility.new(_protect_all.bind(B),
				"All creatures have protection from black.").changing_abilities())
		"Absolute Law":
			c.static_ability(StaticAbility.new(_protect_all.bind(R),
				"All creatures have protection from red.").changing_abilities())
		"Angelic Chorus":
			c.triggered(TriggeredAbility.new(ETB, _chorus,
				"Whenever a creature you control enters, you gain life equal to its toughness.",
				_own_creature_entered).capturing(_entering_context))
		"Glorious Anthem":
			c.static_ability(StaticAbility.new(_anthem, "Creatures you control get +1/+1."))
		"Remembrance":
			c.triggered(TriggeredAbility.new(DIES, _remembrance,
				"Whenever a nontoken creature you control dies, you may search your library for a card with the same name as that creature, reveal it, put it into your hand, then shuffle.",
				_own_nontoken_creature_died).capturing(_dead_name_context))
		"Serra's Liturgy":
			verse(c)
			c.activated(ActivatedAbility.new("{W}", false, [DestroyEffect.new(TargetSpec.new(
					TargetSpec.Kind.PERMANENT, "target artifacts and/or enchantments", _artifact_or_enchantment)) \
					.targets_counted_by(verse_count)],
				"{W}, Sacrifice this enchantment: Destroy up to X target artifacts and/or enchantments, where X is the number of verse counters on this enchantment.") \
				.with_sacrifice_cost())
		"Worship":
			c.static_ability(StaticAbility.new(_worship,
				"If you control a creature, damage that would reduce your life total to less than 1 reduces it to 1 instead."))
		# ------------------------------------------------------------- blue
		"Arcane Laboratory":
			c.bans_playing(_second_spell)
		"Attunement":
			c.activated(ActivatedAbility.new("", false, [DrawEffect.new(3),
					F.Action.new(_discard_four, "discard four cards")],
				"Return this enchantment to its owner's hand: Draw three cards, then discard four cards.") \
				.with_return_cost())
		"Douse":
			c.activated(ActivatedAbility.new("{1}{U}", false,
				[CounterEffect.new("target red spell", _red)], "{1}{U}: Counter target red spell."))
		"Lilting Refrain":
			verse(c)
			c.activated(ActivatedAbility.new("", false, [RefrainCounter.new()],
				"Sacrifice this enchantment: Counter target spell unless its controller pays {X}, where X is the number of verse counters on this enchantment.") \
				.with_sacrifice_cost())
		"Recantation":
			verse(c)
			c.activated(ActivatedAbility.new("{U}", false, [ReturnToHandEffect.new(TargetSpec.new(
					TargetSpec.Kind.PERMANENT, "target permanents")).targets_counted_by(verse_count)],
				"{U}, Sacrifice this enchantment: Return up to X target permanents to their owners' hands, where X is the number of verse counters on this enchantment.") \
				.with_sacrifice_cost())
		"Telepathy":
			c.static_ability(StaticAbility.new(_telepathy, "Your opponents play with their hands revealed."))
		# ------------------------------------------------------------ black
		"Bereavement":
			c.triggered(TriggeredAbility.new(DIES, _bereavement,
				"Whenever a green creature dies, its controller discards a card.", _green_creature_died))
		"Darkest Hour":
			c.static_ability(StaticAbility.new(_darkest_hour, "All creatures are black.").changing_colors())
		"Diabolic Servitude":
			c.triggered(TriggeredAbility.new(ETB, _servitude_raise,
				"When this enchantment enters, return target creature card from your graveyard to the battlefield.",
				F._self_enter).targeting(TargetSpec.new(TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD,
					"target creature card from your graveyard"), _biggest_card_first))
			c.triggered(TriggeredAbility.new(DIES, _servitude_dies,
				"When the creature put onto the battlefield with this enchantment dies, exile it and return this enchantment to its owner's hand.",
				_servitude_creature_died).capturing(_servitude_dead_context))
			c.triggered(TriggeredAbility.new(LEAVES, _servitude_leaves,
				"When this enchantment leaves the battlefield, exile the creature put onto the battlefield with this enchantment.",
				_servitude_self_leaving).capturing(_servitude_leave_context))
		"Discordant Dirge":
			verse(c)
			c.activated(ActivatedAbility.new("{B}", false, [DirgeDiscard.new()],
				"{B}, Sacrifice this enchantment: Look at target opponent's hand and choose up to X cards from it, where X is the number of verse counters on this enchantment. That player discards those cards.") \
				.with_sacrifice_cost())
		"No Rest for the Wicked":
			c.activated(ActivatedAbility.new("", false, [F.Action.new(_no_rest,
					"return to your hand all creature cards in your graveyard that were put there from the battlefield this turn",
					null, true)],
				"Sacrifice this enchantment: Return to your hand all creature cards in your graveyard that were put there from the battlefield this turn.") \
				.with_sacrifice_cost())
		"Oppression":
			c.triggered(TriggeredAbility.new(CAST, _oppression,
				"Whenever a player casts a spell, that player discards a card."))
		"Tainted Aether":
			c.triggered(TriggeredAbility.new(ETB, _tainted_aether,
				"Whenever a creature enters, its controller sacrifices a creature or land of their choice.",
				_creature_entered).capturing(_entering_context))
		"Vile Requiem":
			verse(c)
			c.activated(ActivatedAbility.new("{1}{B}", false, [DestroyEffect.new(
					TargetSpec.creature("target nonblack creatures", _nonblack), false) \
					.targets_counted_by(verse_count)],
				"{1}{B}, Sacrifice this enchantment: Destroy up to X target nonblack creatures, where X is the number of verse counters on this enchantment. They can't be regenerated.") \
				.with_sacrifice_cost())
		"Yawgmoth's Edict":
			c.triggered(TriggeredAbility.new(CAST, _edict,
				"Whenever an opponent casts a white spell, that player loses 1 life and you gain 1 life.",
				_opponent_white_spell))
		# -------------------------------------------------------------- red
		"Antagonism":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _antagonism,
				"At the beginning of each player's end step, this enchantment deals 2 damage to that player unless one of their opponents was dealt damage this turn."))
		"Bedlam":
			c.static_ability(StaticAbility.new(_bedlam, "Creatures can't block."))
		"Bulwark":
			c.triggered(TriggeredAbility.new(UPKEEP, _bulwark,
				"At the beginning of your upkeep, this enchantment deals X damage to target opponent, where X is the number of cards in your hand minus the number of cards in that player's hand.",
				F._your_upkeep).targeting(TargetSpec.opponent()))
		"Rumbling Crescendo":
			verse(c)
			c.activated(ActivatedAbility.new("{R}", false, [DestroyEffect.new(TargetSpec.new(
					TargetSpec.Kind.PERMANENT, "target lands", _land)).targets_counted_by(verse_count)],
				"{R}, Sacrifice this enchantment: Destroy up to X target lands, where X is the number of verse counters on this enchantment.") \
				.with_sacrifice_cost())
		"Scald":
			c.triggered(TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _scald,
				"Whenever a player taps an Island for mana, this enchantment deals 1 damage to that player.",
				_island_tapped))
		"Sneak Attack":
			c.activated(ActivatedAbility.new("{R}", false, [F.Action.new(_sneak_attack,
					"you may put a creature card from your hand onto the battlefield; it gains haste; sacrifice it at the beginning of the next end step",
					null, true)],
				"{R}: You may put a creature card from your hand onto the battlefield. That creature gains haste. Sacrifice the creature at the beginning of the next end step."))
		"Sulfuric Vapors":
			c.static_ability(StaticAbility.new(_vapors,
				"If a red spell would deal damage to a permanent or player, it deals that much damage plus 1 to that permanent or player instead."))
		"Torch Song":
			verse(c)
			c.activated(ActivatedAbility.new("{2}{R}", false, [TorchBlast.new()],
				"{2}{R}, Sacrifice this enchantment: It deals X damage to any target, where X is the number of verse counters on this enchantment.") \
				.with_sacrifice_cost())
		# ------------------------------------------------------------ green
		"Abundance":
			c.replaces_draws(_abundance, _abundance_applies)
		"Crosswinds":
			c.static_ability(StaticAbility.new(_crosswinds, "Creatures with flying get -2/-0."))
		"Exploration":
			c.static_ability(StaticAbility.new(_exploration, "You may play an additional land on each of your turns."))
		"Fecundity":
			c.triggered(TriggeredAbility.new(DIES, _fecundity,
				"Whenever a creature dies, that creature's controller may draw a card.", _creature_died))
		"Greater Good":
			c.activated(ActivatedAbility.new("", false, [F.Action.new(_greater_good,
					"draw cards equal to the sacrificed creature's power, then discard three cards", null, true)],
				"Sacrifice a creature: Draw cards equal to the sacrificed creature's power, then discard three cards.") \
				.with_sacrifice_of("creature", _creature).may_sacrifice_itself())
		"Greener Pastures":
			c.triggered(TriggeredAbility.new(UPKEEP, _pastures,
				"At the beginning of each player's upkeep, if that player controls more lands than each other player, the player creates a 1/1 green Saproling creature token.",
				_upkeep_player_has_most_lands).capturing(_upkeep_player_context))
		"Midsummer Revel":
			verse(c)
			c.activated(ActivatedAbility.new("{G}", false, [RevelBeasts.new()],
				"{G}, Sacrifice this enchantment: Create X 3/3 green Beast creature tokens, where X is the number of verse counters on this enchantment.") \
				.with_sacrifice_cost())
		"Retaliation":
			var retaliate := TriggeredAbility.new(Mtg.EventType.BLOCKED, _retaliate,
				"Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn.",
				_blocked_me).capturing(F._source_context)
			c.static_ability(StaticAbility.new(_grant_retaliation.bind(retaliate),
				"Creatures you control have \"Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn.\"") \
				.changing_abilities().granting_triggers([Mtg.EventType.BLOCKED]))
		"Sporogenesis":
			c.triggered(TriggeredAbility.new(UPKEEP, _sporogenesis,
				"At the beginning of your upkeep, you may put a fungus counter on target nontoken creature.",
				F._your_upkeep).targeting(TargetSpec.creature("target nontoken creature", _nontoken), _theirs_first))
			c.triggered(TriggeredAbility.new(DIES, _fungus_spores,
				"Whenever a creature with a fungus counter on it dies, create a 1/1 green Saproling creature token for each fungus counter on that creature.",
				_fungus_creature_died))
			c.triggered(TriggeredAbility.new(LEAVES, _fungus_cleared,
				"When this enchantment leaves the battlefield, remove all fungus counters from all creatures.",
				F._self_enter))
		"War Dance":
			verse(c)
			c.activated(ActivatedAbility.new("", false, [WarDancePump.new()],
				"Sacrifice this enchantment: Target creature gets +X/+X until end of turn, where X is the number of verse counters on this enchantment.") \
				.with_sacrifice_cost())
		_: return false
	return true


# ============================================================ shared helpers
# Read by cards/sets/ulg/_enchantments.gd as well.

static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _anything(_i: CardInstance) -> bool: return true
static func _land(i: CardInstance) -> bool: return i.is_land()
static func _nontoken(i: CardInstance) -> bool: return not i.is_token
static func _nonblack(i: CardInstance) -> bool: return (i.cur_colors & B) == 0
static func _red(i: CardInstance) -> bool: return (i.cur_colors & R) != 0

static func _artifact_or_enchantment(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) or i.is_type(Mtg.CardType.ENCHANTMENT)


## The seat a resolving trigger or ability of [param s] acts for.
static func you(g: MtgGame, s: CardInstance) -> int:
	return MC.pid_of(g, s)


## "Sacrifice this enchantment" inside its own trigger: only the object
## that triggered, still on the battlefield, by the player who controls it
## (CR 701.17a). Its other instructions happen anyway.
static func sacrifice_self(g: MtgGame, s: CardInstance) -> void:
	if F._trigger_source_present(g, s) and s.controller_id == you(g, s):
		g.sacrifice_permanent(s)


## The lands [param pid] controls, phased-out ones excluded (CR 702.26b).
static func lands_of(g: MtgGame, pid: int) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if g.is_present(i) and i.is_land(): n += 1
	return n


## "If that player controls more lands than each other player."
static func has_most_lands(g: MtgGame, pid: int) -> bool:
	if pid < 0 or pid >= g.players.size(): return false
	var mine := lands_of(g, pid)
	for other in g.players.size():
		if other != pid and lands_of(g, other) >= mine: return false
	return true


static func _upkeep_player_has_most_lands(g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	return has_most_lands(g, int(e.data.get("player", -1)))


## The upkeep's player, beside the source's own context.
static func _upkeep_player_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	ctx["player"] = int(e.data.get("player", -1))
	return ctx


## Discard [param n] cards of [param pid]'s choice — all of them when the
## hand is smaller; a short answer is filled from the hand.
static func discard_n(g: MtgGame, pid: int, n: int) -> void:
	var want := mini(n, g.players[pid].hand.size())
	if want <= 0: return
	var chosen := g.agents[pid].choose_discard(g, pid, want)
	g.discard_cards(pid, chosen)
	var gone := chosen.size()
	while gone < want and not g.players[pid].hand.is_empty():
		g.discard_cards(pid, [g.players[pid].hand[-1]])
		gone += 1


## [param candidates] ranked least valuable first (the public board only):
## the heuristic seat's answer for what IT loses.
static func cheapest_first(candidates: Array[CardInstance]) -> Array[CardInstance]:
	var ranked: Array[CardInstance] = candidates.duplicate()
	ranked.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var va := Evaluator.permanent_value(a)
		var vb := Evaluator.permanent_value(b)
		return va < vb if va != vb else a.id < b.id)
	return ranked


# ------------------------------------------------------------ verse counters --

## The verse-counter upkeep trigger of [param c].
static func verse(c: CardData) -> void:
	c.triggered(TriggeredAbility.new(UPKEEP, _verse_upkeep, VERSE_LINE, F._your_upkeep))


## "You may put a verse counter on this enchantment" — on the object that
## triggered, while it is still here.
static func _verse_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := you(g, s)
	if g.agents[pid].choose_yes_no(g, pid, "Put a verse counter on %s?" % s.data.card_name, true):
		g.add_counters(s, "verse")


## "Up to X targets": the count as the ability is announced — the
## enchantment is still on the battlefield (targets before costs, CR 601.2c
## / 602.2b); after the sacrifice, as it last existed (CR 608.2h).
static func verse_count(_g: MtgGame, s: CardInstance, _earlier: Array) -> Vector2i:
	if s == null: return Vector2i(0, 0)
	var counters: Dictionary = s.counters if s.zone == Mtg.Zone.BATTLEFIELD else s.last_counters
	return Vector2i(0, int(counters.get("verse", 0)))


## In the classes below X is the verse counters the enchantment had as it
## was sacrificed for the ability now resolving — recorded with the cost
## (`_source_counters`, CR 608.2h).

## Lilting Refrain: "Counter target spell unless its controller pays {X}."
class RefrainCounter extends CounterEffect:
	func _init() -> void:
		super("target spell")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var spell := g.find_instance(t.instance_id)
		if spell == null: return
		var item := g.find_stack_item(spell)
		var payer := spell.controller_id if item == null else item.controller
		var paid: Dictionary = g.cost_paid("_source_counters", {})
		var x := int(paid.get("verse", 0))
		var toll := "{%d}" % x
		if EffectBase.unless_paid(g, payer, ManaCost.parse(toll),
				"Pay %s to prevent Lilting Refrain's counter?" % toll):
			return
		g.counter_spell(spell)
	func describe() -> String:
		return "counter target spell unless its controller pays {X}, where X is the number of verse counters on this enchantment"


## Discordant Dirge: the activator sees the whole hand (that seat only) and
## chooses up to X cards from it, X fixed by the sacrifice.
class DirgeDiscard extends ChosenDiscardEffect:
	func _init() -> void:
		super(0)
		target_spec = TargetSpec.opponent()
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or not t.is_player: return
		var who := t.player_id
		var names: Array = []
		for card in g.players[who].hand: names.append(card.data.card_name)
		g.reveal_information(pid, "Discordant Dirge — %s's hand" % g.players[who].player_name, names)
		var left := candidates(g, who)
		# The look is the card's own: the ranking reads the revealed hand.
		left.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return a.data.cost.mana_value() > b.data.cost.mana_value())
		var paid: Dictionary = g.cost_paid("_source_counters", {})
		var x := int(paid.get("verse", 0))
		var chosen: Array[CardInstance] = []
		for _i in mini(x, left.size()):
			var pick := g.agents[pid].choose_card(g, pid, left,
				"Discordant Dirge: choose a card for %s to discard (up to %d)" % [
					g.players[who].player_name, x], true)
			if pick == null or not left.has(pick): break
			chosen.append(pick)
			left.erase(pick)
		if not chosen.is_empty(): g.discard_cards(who, chosen)
	func describe() -> String:
		return "look at target opponent's hand and choose up to X cards from it, where X is the number of verse counters on this enchantment; that player discards those cards"


## Torch Song: the departed enchantment is the source (CR 113.7a). Its line
## is the counter-blast shape the fair AI reads (mirage_tactics.counter_damage).
class TorchBlast extends DamageEffect:
	func _init() -> void:
		super(0)
		any_target()
	func resolve(g: MtgGame, source: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var paid: Dictionary = g.cost_paid("_source_counters", {})
		var n := int(paid.get("verse", 0))
		if n > 0: g.deal_damage(source, t, n)
	func describe() -> String:
		return "deals damage equal to the number of verse counters on it to any target"


## Midsummer Revel: X 3/3 green Beasts for the activator.
class RevelBeasts extends CreateTokenEffect:
	func _init() -> void:
		super("Beast", 3, 3, Mtg.ManaColor.G, "beast")
	func resolve(g: MtgGame, _s: CardInstance, controller: int, _t: TargetRef, _x := 0) -> void:
		var paid: Dictionary = g.cost_paid("_source_counters", {})
		var n := int(paid.get("verse", 0))
		if n > 0: g.create_token(controller, token, n)
	func describe() -> String:
		return "create X 3/3 green Beast creature tokens, where X is the number of verse counters on this enchantment"


## War Dance: +X/+X until end of turn on the target.
class WarDancePump extends PumpEffect:
	func _init() -> void:
		super(0, 0)
	func resolve(g: MtgGame, source: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var target := g.find_instance(t.instance_id)
		if not g.is_present(target): return
		var paid: Dictionary = g.cost_paid("_source_counters", {})
		var n := int(paid.get("verse", 0))
		g.continuous.add_until_eot_pump(target.id, n, n)
		g.log_line("%s gives %s %+d/%+d until end of turn" % [source.data.card_name, target, n, n])
		g.recalculate()
	func describe() -> String:
		return "target creature gets +X/+X until end of turn, where X is the number of verse counters on this enchantment"


# ======================================================================= white

## Protection is an ability (layer 6, CR 702.16): every creature, both
## players'. A granted protection sheds Auras of that color by SBA.
static func _protect_all(g: MtgGame, _s: CardInstance, color: int) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): i.cur_protection |= color


static func _anthem(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature():
			i.cur_power += 1
			i.cur_toughness += 1


# ------------------------------------------------------------ Angelic Chorus --

static func _own_creature_entered(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var entrant: CardInstance = e.data.get("instance")
	return entrant != null and entrant.is_creature() \
		and int(e.data.get("controller", entrant.controller_id)) == s.controller_id


static func _creature_entered(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var entrant: CardInstance = e.data.get("instance")
	return entrant != null and entrant.is_creature()


## The entering creature's incarnation, beside the source's own context.
static func _entering_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var entrant: CardInstance = e.data.get("instance")
	ctx["id"] = entrant.id
	ctx["stamp"] = entrant.layer_timestamp
	ctx["entered_under"] = int(e.data.get("controller", entrant.controller_id))
	return ctx


## The entering creature as the trigger resolves: still that object
## (CR 400.7), or null.
static func _entrant(g: MtgGame, s: CardInstance) -> CardInstance:
	var ctx := g.trigger_context(s)
	var i := g.find_instance(int(ctx.get("id", -1)))
	if i != null and i.layer_timestamp == int(ctx.get("stamp", -2)): return i
	return null


## Its toughness as the ability resolves — live, or as it last existed on
## the battlefield if it has left (CR 608.2h).
static func _chorus(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var entrant := _entrant(g, s)
	if entrant == null: return
	var toughness := entrant.cur_toughness if entrant.zone == Mtg.Zone.BATTLEFIELD else entrant.last_toughness
	if toughness > 0: g.adjust_life(you(g, s), toughness)


# --------------------------------------------------------------- Remembrance --

static func _own_nontoken_creature_died(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and not dead.is_token and (dead.last_types & Mtg.CardType.CREATURE) != 0 \
		and int(e.data.get("controller", -1)) == s.controller_id


## "That creature"'s name as it last existed on the battlefield (CR 608.2h),
## read as the trigger is put on the stack: a dead Clone that copied
## Grizzly Bears is a card named Clone again by the time the ability
## resolves (CR 707.2), but it died as "Grizzly Bears".
static func _dead_name_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var dead: CardInstance = e.data.get("instance")
	if dead != null: ctx["name"] = dead.data.card_name
	return ctx


## "You may search": declining searches nothing and shuffles nothing; a
## search may fail to find (CR 701.19b). The found card is revealed.
static func _remembrance(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var dead: CardInstance = e.data.get("instance")
	if dead == null: return
	var card_name := String(g.trigger_context(s).get("name", dead.data.card_name))
	var pid := you(g, s)
	if not g.agents[pid].choose_yes_no(g, pid,
			"Remembrance: search your library for a card named %s?" % card_name, true):
		return
	g.search_library(pid, func(i: CardInstance) -> bool: return i.data.card_name == card_name,
		"Remembrance: choose a card named %s" % card_name, false, true, "Remembrance reveals")


# ------------------------------------------------------------------- Worship --

static func _worship(g: MtgGame, s: CardInstance) -> void:
	var pid := s.controller_id
	for i in g.players[pid].battlefield:
		if g.is_present(i) and i.is_creature():
			g.players[pid].min_life_from_damage = maxi(1, g.players[pid].min_life_from_damage)
			return


# ======================================================================== blue

## "Each player can't cast more than one spell each turn": a spell is
## banned once its caster has cast one this turn (copies are not cast; a
## land is never a spell).
static func _second_spell(g: MtgGame, pid: int, data: CardData) -> bool:
	return not data.is_land() and g.spells_cast_count(pid) >= 1


static func _discard_four(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	discard_n(g, pid, 4)


static func _telepathy(g: MtgGame, s: CardInstance) -> void:
	for pid in g.players.size():
		if pid != s.controller_id: g.players[pid].hand_revealed = true


# ======================================================================= black

# ------------------------------------------------------------- Bereavement --

static func _green_creature_died(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and (dead.last_types & Mtg.CardType.CREATURE) != 0 \
		and (dead.last_colors & G) != 0


## Its controller as it died discards a card of their choice.
static func _bereavement(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("controller", -1))
	if who >= 0: discard_n(g, who, 1)


static func _darkest_hour(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): i.cur_colors = B


# ------------------------------------------------------ Diabolic Servitude --

const SERVITUDE := "servitude"

## The biggest creature card first (the heuristic seat's pick).
static func _biggest_card_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ia := g.find_instance(a.instance_id)
	var ib := g.find_instance(b.instance_id)
	var va := ia.data.power + ia.data.toughness + ia.data.cost.mana_value()
	var vb := ib.data.power + ib.data.toughness + ib.data.cost.mana_value()
	return va > vb if va != vb else ia.id < ib.id


## The creature returns even if the Servitude has already left; only the
## Servitude that is still the object that entered is linked to it.
static func _servitude_raise(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var t := g.current_trigger_target(0)
	if t == null: return
	var card := g.find_instance(t.instance_id)
	if card == null or card.zone != Mtg.Zone.GRAVEYARD: return
	g.reanimate(card, you(g, s))
	if card.zone != Mtg.Zone.BATTLEFIELD or not F._same_trigger_source(g, s): return
	g._rec(s, &"memory")
	s.memory[SERVITUDE] = [card.id, card.layer_timestamp]


static func _servitude_creature_died(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var link: Array = s.memory.get(SERVITUDE, [])
	var dead: CardInstance = e.data.get("instance")
	return link.size() == 2 and dead != null and dead.id == int(link[0]) \
		and dead.layer_timestamp == int(link[1])


static func _servitude_dead_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var dead: CardInstance = e.data.get("instance")
	ctx["id"] = dead.id
	ctx["entry"] = int(e.data.get("graveyard_entry", dead.graveyard_entry))
	return ctx


## "Exile it and return this enchantment to its owner's hand" — the card on
## the graveyard visit its death began (CR 400.7), and this Servitude only
## while it is still the object that heard the death.
static func _servitude_dies(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var card := g.find_instance(int(ctx.get("id", -1)))
	if card != null and card.zone == Mtg.Zone.GRAVEYARD and card.graveyard_entry == int(ctx.get("entry", -2)):
		g.exile_from_graveyard(card)
	if F._same_trigger_source(g, s):
		g._rec(s, &"memory")
		s.memory.erase(SERVITUDE)
		g.return_to_hand(s)


static func _servitude_self_leaving(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var parting: Dictionary = e.data.get("memory", {})
	return e.data.get("instance") == s and parting.has(SERVITUDE)


static func _servitude_leave_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var parting: Dictionary = e.data.get("memory", {})
	ctx["link"] = (parting.get(SERVITUDE, []) as Array).duplicate()
	return ctx


static func _servitude_leaves(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var link: Array = g.trigger_context(s).get("link", [])
	if link.size() != 2: return
	var creature := g.find_instance(int(link[0]))
	if g.is_present(creature) and creature.layer_timestamp == int(link[1]):
		g.exile_permanent(creature)


# ---------------------------------------------------- No Rest for the Wicked --

## Every creature card of the activator's graveyard that DIED this turn —
## the same graveyard visit as its death row (CR 400.7).
static func _no_rest(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var back: Array[CardInstance] = []
	for row in g.deaths_this_turn:
		var card := g.find_instance(int(row.get("id", -1)))
		if card != null and card.zone == Mtg.Zone.GRAVEYARD and card.owner_id == pid \
				and card.graveyard_entry == int(row.get("entry", -2)) \
				and card.data.is_creature() and not back.has(card):
			back.append(card)
	for card in back: g.return_from_graveyard_to_hand(card)


# ---------------------------------------------------------------- Oppression --

static func _oppression(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("controller", -1))
	if who >= 0: discard_n(g, who, 1)


# ------------------------------------------------------------ Tainted Aether --

## "Its controller sacrifices a creature or land of their choice" — the
## creature's controller now, or as it last was if it has left; the
## creature itself is a legal choice.
static func _tainted_aether(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var entrant := _entrant(g, s)
	var who := entrant.controller_id if g.is_present(entrant) else int(ctx.get("entered_under", -1))
	if who < 0: return
	var choices: Array[CardInstance] = []
	for i in g.players[who].battlefield:
		if g.is_present(i) and (i.is_creature() or i.is_land()): choices.append(i)
	if choices.is_empty(): return
	choices = cheapest_first(choices)
	var pick := g.agents[who].choose_card(g, who, choices,
		"Tainted Aether: sacrifice a creature or land", false, false, true)
	if pick == null or not choices.has(pick): pick = choices[0]
	g.sacrifice_permanent(pick)


# ---------------------------------------------------------- Yawgmoth's Edict --

static func _opponent_white_spell(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var spell: CardInstance = e.data.get("instance")
	return spell != null and int(e.data.get("controller", s.controller_id)) != s.controller_id \
		and (spell.cur_colors & W) != 0


static func _edict(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var caster := int(e.data.get("controller", -1))
	if caster < 0: return
	g.adjust_life(caster, -1)
	g.adjust_life(you(g, s), 1)


# ========================================================================= red

## "Unless one of their opponents was dealt damage this turn", read as it
## resolves; the source as it last existed if it has left (CR 113.7a).
static func _antagonism(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	for other in g.players.size():
		if other != who and g.players[other].damage_taken_this_turn > 0: return
	g.deal_damage(s, TargetRef.player(who), 2)


static func _bedlam(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): MC.cant_block(i, _anything)


## X counted on resolution; a negative difference deals nothing (CR 107.1b).
static func _bulwark(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var t := g.current_trigger_target(0)
	if t == null or not t.is_player: return
	var x := g.players[you(g, s)].hand.size() - g.players[t.player_id].hand.size()
	if x > 0: g.deal_damage(s, t, x)


static func _island_tapped(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var land: CardInstance = e.data.get("instance")
	return land != null and land.has_subtype("island")


static func _scald(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", e.data.get("controller", -1)))
	if who >= 0: g.deal_damage(s, TargetRef.player(who), 1)


# -------------------------------------------------------------- Sneak Attack --

## The biggest creature card in hand is the heuristic's pick; "you may"
## is the optional answer (null puts nothing down).
static func _sneak_attack(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var cards: Array[CardInstance] = []
	for card in g.players[pid].hand:
		if card.data.is_creature(): cards.append(card)
	if cards.is_empty(): return
	cards.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var va := a.data.power + a.data.toughness
		var vb := b.data.power + b.data.toughness
		return va > vb if va != vb else a.data.cost.mana_value() > b.data.cost.mana_value())
	var pick := g.agents[pid].choose_card(g, pid, cards,
		"Sneak Attack: put a creature card from your hand onto the battlefield", true)
	if pick == null or not cards.has(pick): return
	g.put_from_hand_into_play(pick, pid)
	if not g.is_present(pick): return
	g.grant_keyword_permanently(pick, Mtg.Keyword.HASTE)
	g.doom_at_next_end_step(pick, false, false, true, pid)


# ----------------------------------------------------------- Sulfuric Vapors --

static func _vapors(g: MtgGame, s: CardInstance) -> void:
	g.add_static_damage_effect(s, {"kind": &"modify", "delta": 1, "spell_only": true,
		"source_filter": _red_source, "desc": "Sulfuric Vapors: a red spell deals 1 more damage"})


static func _red_source(g: MtgGame, source: CardInstance) -> bool:
	return (g.source_colors(source) & R) != 0


# ======================================================================= green

# ----------------------------------------------------------------- Abundance --

const ABUNDANCE_OPTIONS: Array[String] = ["Draw the card", "Reveal until a land", "Reveal until a nonland card"]

static func _abundance_applies(_g: MtgGame, s: CardInstance, pid: int, _ctx: Dictionary) -> bool:
	return pid == s.controller_id


## One question for the whole "you may instead choose land or nonland".
## Returns true when the draw was replaced.
static func _abundance(g: MtgGame, s: CardInstance, pid: int, _ctx: Dictionary) -> bool:
	if pid != s.controller_id: return false
	var pick := g.agents[pid].choose_option(g, pid, ABUNDANCE_OPTIONS,
		"Abundance: draw, or reveal until a land or a nonland card?", _abundance_hint(g, pid))
	if pick != 1 and pick != 2: return false
	var want_land := pick == 1
	var library := g.players[pid].library
	var revealed: Array[CardInstance] = []
	var found: CardInstance = null
	for n in range(library.size() - 1, -1, -1):
		var card: CardInstance = library[n]
		revealed.append(card)
		if card.data.is_land() == want_land:
			found = card
			break
	var who := g.players[pid].player_name
	if revealed.is_empty():
		g.log_line("%s reveals nothing — the library is empty (Abundance)" % who)
		return true
	var names: Array = []
	for card in revealed: names.append(card.data.card_name)
	g.reveal_information(-1, "Abundance reveals", names)
	g.log_line("%s reveals %s (Abundance)" % [who, ", ".join(PackedStringArray(names))])
	if found != null:
		g.library_card_to_hand(found)
		revealed.erase(found)
	bottom_in_order(g, pid, revealed, "Abundance: put a revealed card on the bottom of your library (each goes beneath the last)")
	return true


## The fair hint (own board and hand only): a land while the hand holds
## none and the lands in play are short of the hand's dearest spell (or of
## four), otherwise a spell.
static func _abundance_hint(g: MtgGame, pid: int) -> int:
	var hand_lands := 0
	var dearest := 0
	for card in g.players[pid].hand:
		if card.data.is_land(): hand_lands += 1
		else: dearest = maxi(dearest, card.data.cost.mana_value())
	return 1 if hand_lands == 0 and lands_of(g, pid) < maxi(4, dearest) else 2


## Put [param cards] (library cards of [param pid]) on the bottom one by one
## in the order the player chooses — each goes beneath the last.
static func bottom_in_order(g: MtgGame, pid: int, cards: Array[CardInstance], prompt: String) -> void:
	var left: Array[CardInstance] = cards.duplicate()
	while not left.is_empty():
		var pick: CardInstance = left[0]
		if left.size() > 1:
			var answer := g.agents[pid].choose_card_in_order(g, pid, left, prompt)
			if answer != null and left.has(answer): pick = answer
		left.erase(pick)
		g.put_on_bottom_of_library(pick)


static func _crosswinds(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and i.has_keyword(Mtg.Keyword.FLYING): i.cur_power -= 2


static func _exploration(g: MtgGame, s: CardInstance) -> void:
	g.extra_land_plays[s.controller_id] = int(g.extra_land_plays.get(s.controller_id, 0)) + 1


# ------------------------------------------------------------------ Fecundity --

static func _creature_died(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and (dead.last_types & Mtg.CardType.CREATURE) != 0


## The dead creature's controller is asked — not Fecundity's.
static func _fecundity(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("controller", -1))
	if who < 0: return
	if g.agents[who].choose_yes_no(g, who, "Fecundity: draw a card?", not g.players[who].library.is_empty()):
		g.draw_cards(who, 1)


static func _greater_good(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var power := int(g.cost_paid("_sacrificed_power", 0))
	if power > 0: g.draw_cards(pid, power)
	discard_n(g, pid, 3)


## Intervening "if" (CR 603.4): asked again on resolution; the token is the
## upkeep player's.
static func _pastures(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := int(g.trigger_context(s).get("player", -1))
	if not has_most_lands(g, who): return
	F._saproling().resolve(g, s, who, null)


# ---------------------------------------------------------------- Retaliation --

static func _grant_retaliation(g: MtgGame, s: CardInstance, retaliate: TriggeredAbility) -> void:
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature(): i.cur_triggered_abilities.append(retaliate)


## One BLOCKED event per blocking creature (CR 509.3c): one trigger each.
static func _blocked_me(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("attacker") == s and e.data.get("blocker") != null


static func _retaliate(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	g.continuous.add_until_eot_pump(s.id, 1, 1)
	g.log_line("%s gets +1/+1 until end of turn (Retaliation)" % s.data.card_name)
	g.recalculate()


# -------------------------------------------------------------- Sporogenesis --

## The opponent's creatures first: their deaths feed the Saprolings too.
static func _theirs_first(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ia := g.find_instance(a.instance_id)
	var ib := g.find_instance(b.instance_id)
	var them_a := ia.controller_id != s.controller_id
	var them_b := ib.controller_id != s.controller_id
	if them_a != them_b: return them_a
	return ia.id < ib.id


static func _sporogenesis(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var t := g.current_trigger_target(0)
	if t == null: return
	var target := g.find_instance(t.instance_id)
	if not g.is_present(target): return
	var pid := you(g, s)
	if g.agents[pid].choose_yes_no(g, pid, "Sporogenesis: put a fungus counter on %s?" % target.data.card_name, true):
		g.add_counters(target, "fungus")


static func _fungus_creature_died(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and (dead.last_types & Mtg.CardType.CREATURE) != 0 \
		and int(dead.last_counters.get("fungus", 0)) > 0


## One Saproling per fungus counter the creature had as it died (CR 608.2h).
static func _fungus_spores(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var dead: CardInstance = e.data.get("instance")
	var n := int(dead.last_counters.get("fungus", 0)) if dead != null else 0
	if n <= 0: return
	var spores := F._saproling()
	spores.count = n
	spores.resolve(g, s, you(g, s), null)


static func _fungus_cleared(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for i in g.all_battlefield():
		var n := int(i.counters.get("fungus", 0))
		if n > 0 and i.is_creature(): g.remove_counters(i, "fungus", n)
