extends RefCounted
## Urza's Destiny (_enchantments, Pack 10). Non-Aura enchantments: global statics, triggers and activations.
##
## - Sanctimony: TAPPED_FOR_MANA with the ACTING player (`player`, the hand
##   that tapped — 2ed/manabarbs.gd's reading) an opponent and the land a
##   Mountain by its live subtype. It adds no mana, so it is an ordinary
##   trigger that uses the stack (CR 605.1b names only triggers that add
##   mana); "you may" is asked as it resolves.
## - Opposition: "Tap an untapped creature you control" is not {T}: a
##   summoning-sick creature may pay it (CR 302.6), Opposition itself only
##   while something makes it a creature (tmp Tradewind Rider's
##   `tap_permanent_filter`).
## - Attrition: the sacrifice is a cost (CR 601.2h) paid after the target is
##   chosen — the target may be sacrificed, and the ability then fizzles.
##   Under Opalescence Attrition is "a creature" itself and may pay with its
##   own body; the ability still resolves (CR 113.7a).
## - Carnival of Souls: every creature entering, either side; the {B} is
##   added as the trigger resolves (it is not a mana ability, CR 605.1a/b)
##   and empties with the step.
## - Yawgmoth's Bargain: its controller's draw step is replaced away
##   (CardData.replaces_draw_step — no draw, no priority in it, CR 614.1);
##   "Pay 1 life" may take its controller to 0 (CR 119.4, 704.5a).
## - Aether Sting: SPELL_CAST by an opponent of a creature spell; the
##   enchantment deals the damage as it last existed if it has left.
## - Goblin Festival: the 1 damage, then the flip by the activator
##   (MtgGame.flip_coin, the duel RNG); a lost flip hands this enchantment
##   to the opponent they choose — indefinitely (MtgGame.change_control) —
##   only while it is still the object that was activated (CR 400.7).
## - Impatience: an intervening "if" (CR 603.4) — checked as the trigger is
##   put on the stack and again as it resolves (MtgGame.spells_cast_count,
##   cleared at cleanup).
## - Repercussion: WAS_DEALT_DAMAGE, one per creature per damage event for
##   the total (CR 510.2); "that creature's controller" as it was dealt the
##   damage, captured then.
## tests/cards/test_pack_10_B7_*.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/mir/_auras.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Sanctimony":
			c.triggered(TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _sanctimony,
				"Whenever an opponent taps a Mountain for mana, you may gain 1 life.", _opponent_tapped_mountain))
		"Mental Discipline":
			c.activated(ActivatedAbility.new("{1}{U}", false, [DrawEffect.new(1)],
				"{1}{U}, Discard a card: Draw a card.").with_discard_cost(1))
		"Opposition":
			var opposition := ActivatedAbility.new("", false,
				[TapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact, creature, or land",
					_artifact_creature_or_land))],
				"Tap an untapped creature you control: Tap target artifact, creature, or land.")
			opposition.tap_permanent_filter = _creature
			opposition.tap_permanent_count = 1
			c.activated(opposition)
		"Attrition":
			c.activated(ActivatedAbility.new("{B}", false,
				[DestroyEffect.new(TargetSpec.creature("target nonblack creature", _nonblack).because("color"))],
				"{B}, Sacrifice a creature: Destroy target nonblack creature.").with_sacrifice_of("creature", _creature) \
				.may_sacrifice_itself())
		"Carnival of Souls":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _carnival,
				"Whenever a creature enters, you lose 1 life and add {B}.", _a_creature_entered))
		"Yawgmoth's Bargain":
			c.replaces_draw_step(_bargain_skip)
			c.activated(ActivatedAbility.new("", false, [DrawEffect.new(1)],
				"Pay 1 life: Draw a card.").with_life_cost(1))
		"Aether Sting":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _aether_sting,
				"Whenever an opponent casts a creature spell, this enchantment deals 1 damage to that player.",
				_opponent_creature_spell))
		"Goblin Festival":
			c.activated(ActivatedAbility.new("{2}", false,
				[DamageEffect.new(1).any_target(),
					F.Action.new(_festival_flip, "flip a coin; if you lose the flip, an opponent you choose gains control of this enchantment")],
				"{2}: This enchantment deals 1 damage to any target. Flip a coin. If you lose the flip, choose one of your opponents. That player gains control of this enchantment."))
		"Impatience":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _impatience,
				"At the beginning of each player's end step, if that player didn't cast a spell this turn, this enchantment deals 2 damage to that player.",
				_cast_nothing))
		"Repercussion":
			c.triggered(TriggeredAbility.new(Mtg.EventType.WAS_DEALT_DAMAGE, _repercussion,
				"Whenever a creature is dealt damage, this enchantment deals that much damage to that creature's controller.",
				_a_creature_was_dealt_damage).capturing(_damaged_context))
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _nonblack(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) == 0
static func _artifact_creature_or_land(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) or i.is_creature() or i.is_land()


# ------------------------------------------------------------------ Sanctimony --

static func _opponent_tapped_mountain(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var land: CardInstance = e.data.get("instance")
	return land != null and land.has_subtype("mountain") \
		and int(e.data.get("player", -1)) != s.controller_id

static func _sanctimony(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := A.pid_of(g, s)
	if g.agents[pid].choose_yes_no(g, pid, "Sanctimony: gain 1 life?", true):
		g.adjust_life(pid, 1)


# ------------------------------------------------------------ Carnival of Souls --

static func _a_creature_entered(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.get("instance")
	return i != null and i.is_creature()

static func _carnival(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := A.pid_of(g, s)
	g.adjust_life(pid, -1)
	g.players[pid].mana_pool.add(Mtg.ManaColor.B, 1)
	g.log_line("Carnival of Souls: %s loses 1 life and adds {B}" % g.players[pid].player_name, s)


# ----------------------------------------------------------- Yawgmoth's Bargain --

static func _bargain_skip(g: MtgGame, s: CardInstance, pid: int) -> bool:
	if pid != s.controller_id or not g.is_present(s) or s.cur_abilities_silenced: return false
	g.log_line("Yawgmoth's Bargain: %s skips their draw step" % g.players[pid].player_name, s)
	return true


# ----------------------------------------------------------------- Aether Sting --

static func _opponent_creature_spell(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var spell: CardInstance = e.data.get("instance")
	return spell != null and spell.data.is_creature() \
		and int(e.data.get("controller", -1)) != s.controller_id

static func _aether_sting(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("controller", -1))
	if who >= 0: g.deal_damage(s, TargetRef.player(who), 1)


# -------------------------------------------------------------- Goblin Festival --

static func _festival_flip(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if g.flip_coin(pid): return
	if not F._same_activation_source(g, s): return
	var foe := g.choose_opponent(pid, s)
	if foe != s.controller_id: g.change_control(s, foe)


# ------------------------------------------------------------------- Impatience --

## The intervening "if", read as the trigger is put on the stack.
static func _cast_nothing(g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	return g.spells_cast_count(int(e.data.get("player", g.active_player))) == 0

## ... and again as it resolves (CR 603.4): a spell cast in response stops it.
static func _impatience(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", g.active_player))
	if g.spells_cast_count(who) == 0:
		g.deal_damage(s, TargetRef.player(who), 2)


# ----------------------------------------------------------------- Repercussion --

static func _a_creature_was_dealt_damage(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var hit: CardInstance = e.data.get("to_instance")
	return hit != null and hit.is_creature() and int(e.data.get("amount", 0)) > 0

static func _damaged_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var out := F._source_context(g, s, e)
	var hit: CardInstance = e.data.get("to_instance")
	out["amount"] = int(e.data.get("amount", 0))
	out["victim"] = hit.controller_id
	return out

static func _repercussion(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var amount := int(ctx.get("amount", 0))
	if amount > 0:
		g.deal_damage(s, TargetRef.player(int(ctx.get("victim", s.controller_id))), amount)
