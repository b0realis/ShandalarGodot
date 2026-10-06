extends RefCounted
## Stronghold (_combat, Pack 9). Combat rules: blocking and attacking restrictions, combat triggers.
##
## - Dream Prowler is "attacking alone" while it is the only attacking
##   creature (CR 506.5) — a live state, read by a static each
##   recalculation; while it holds, the Prowler can't be blocked.
## - Duct Crawler's ban is a floating static bound to the TARGET for the
##   turn, naming the Crawler as the object it was when the ability was
##   activated (CR 400.7): a Crawler that left and came back is a new one.
## - Mogg Flunkies: "can't attack or block alone" is a minimum group of two
##   (CR 506.5, the Orcish Conscripts shape — CombatState checks it).
## - Rolling Stones lifts defender's attack ban for Walls without removing
##   defender ("as though it didn't have defender",
##   cur_can_attack_with_defender).
## - Invasion Plans (Pack 9 E4): every creature blocks each combat if able
##   (CR 509.1c), and the attacking player declares the blocks — the
##   Melee override (block_chooser_override), kept only while the
##   enchantment is there with its abilities.
## - Provoke (E4): the creature blocks this turn if able — ONE block
##   against any attacker it can legally block at no cost
##   (MtgGame.require_block_this_turn).
## - Wall of Tears: each block makes one delayed trigger (CR 603.7) at the
##   end of combat that returns that attacker if it is still the same
##   object (CR 400.7); it is the Wall's trigger's controller's.
## tests/cards/test_pack_9_B10_combat.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const MC := preload("res://cards/sets/mir/_combat.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Dream Prowler":
			c.static_ability(StaticAbility.new(_prowler,
				"This creature can't be blocked as long as it's attacking alone.").changing_abilities())
		"Duct Crawler":
			c.activated(ActivatedAbility.new("{1}{R}", false,
				[F.Action.new(_crawler, "target creature can't block this creature this turn", TargetSpec.creature()) \
					.with_ai_role(&"cant_block_source")],
				"{1}{R}: Target creature can't block this creature this turn."))
		"Hammerhead Shark":
			c.with_attack_needs_defender_land("island")
		"Invasion Plans":
			c.static_ability(StaticAbility.new(_plans,
				"All creatures block each combat if able. The attacking player chooses how each creature blocks each combat."))
		"Mogg Flunkies":
			c.static_ability(StaticAbility.new(_flunkies, "This creature can't attack or block alone."))
		"Provoke":
			c.spell(F.Action.new(_provoke, "untap target creature you don't control; that creature blocks this turn if able",
				TargetSpec.creature("target creature you don't control").with_source_filter(_not_yours).because("controller")) \
				.with_ai_role(&"force_block"))
			c.spell(DrawEffect.new(1))
		"Rabid Rats":
			var shrink := PumpEffect.new(-1, -1)
			shrink.target_spec = TargetSpec.creature("target blocking creature").with_game_filter(F._blocking).because("blocking")
			c.activated(ActivatedAbility.new("", true, [shrink], "{T}: Target blocking creature gets -1/-1 until end of turn."))
		"Rolling Stones":
			c.static_ability(StaticAbility.new(_rolling_stones,
				"Wall creatures can attack as though they didn't have defender."))
		"Wall of Tears":
			c.triggered(MC.pair_trigger(MC.BLOCKS, Callable(), _tears,
				"Whenever this creature blocks a creature, return that creature to its owner's hand at end of combat."))
		_: return false
	return true


static func _not_yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s != null and i.controller_id != g.controller_acting_for(s)

static func _live(g: MtgGame, id: int, stamp: int) -> CardInstance:
	var i := g.find_instance(id)
	return i if g.is_present(i) and i.layer_timestamp == stamp else null


# ------------------------------------------------------------- Dream Prowler --

static func _prowler(g: MtgGame, s: CardInstance) -> void:
	if g.combat.attackers.size() == 1 and g.combat.attackers.has(s.id) \
			and not s.cur_keywords.has(Mtg.Keyword.UNBLOCKABLE):
		s.cur_keywords.append(Mtg.Keyword.UNBLOCKABLE)


# -------------------------------------------------------------- Duct Crawler --

## The Crawler named is the object that paid for the ability; a ban
## without it (it left before resolution) names nothing on the table.
static func _crawler(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if t == null or s == null: return
	var i := g.find_instance(t.instance_id)
	if not g.is_present(i): return
	var stamp := int(g.cost_paid("_source_timestamp", s.layer_timestamp))
	g.continuous.add_floating_static(s, StaticAbility.new(
		_crawler_ban.bind(i.id, i.layer_timestamp, s.id, stamp),
		"Can't block Duct Crawler this turn."),
		ContinuousEffects.Duration.END_OF_TURN, -1, false, i.id)
	g.log_line("%s can't block %s this turn" % [i.data.card_name, s.data.card_name])
	g.recalculate()

static func _crawler_ban(g: MtgGame, _s: CardInstance, id: int, stamp: int, crawler_id: int, crawler_stamp: int) -> void:
	var i := _live(g, id, stamp)
	if i == null: return
	MC.cant_block(i, func(attacker: CardInstance) -> bool:
		return attacker.id == crawler_id and attacker.layer_timestamp == crawler_stamp)


# ------------------------------------------------------------ Invasion Plans --

static func _plans(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): i.cur_must_block = true
	g.block_chooser_override = g.active_player


# -------------------------------------------------------------- Mogg Flunkies --

static func _flunkies(_g: MtgGame, s: CardInstance) -> void:
	s.cur_min_attack_group = maxi(s.cur_min_attack_group, 2)
	s.cur_min_block_group = maxi(s.cur_min_block_group, 2)


# -------------------------------------------------------------------- Provoke --

static func _provoke(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if t == null: return
	var i := g.find_instance(t.instance_id)
	if not g.is_present(i): return
	g.untap_permanent(i)
	g.require_block_this_turn(i)
	g.log_line("%s blocks this turn if able" % i.data.card_name)


# ------------------------------------------------------------- Rolling Stones --

static func _rolling_stones(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and i.has_subtype("wall"): i.cur_can_attack_with_defender = true


# -------------------------------------------------------------- Wall of Tears --

static func _tears(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var id := int(ctx.get("other", -1))
	if id < 0: return
	var pid := int(ctx.get("controller", s.controller_id))
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT,
		_tears_return.bind(id, int(ctx.get("other_stamp", -1))),
		"Return that creature to its owner's hand."), pid, s)

static func _tears_return(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := _live(g, id, stamp)
	if i != null: g.return_to_hand(i)
