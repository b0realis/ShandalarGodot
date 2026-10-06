extends RefCounted
## Tempest (_spells, Pack 9). Instants and sorceries: one-shot spell effects,
## modes, X spells and their targets.
##
## Effects are TYPED wherever the engine has the shape — the fair AI reads
## them (engine/ai/effect_intent.gd) — and a card-local class subclasses the
## typed effect it most resembles (Kindle and Sudden Impact are
## DamageEffects whose amount is counted as they resolve, Serene Offering a
## DestroyEffect that pays out, Winds of Rath a DestroyAllEffect with a
## game-aware filter), so its intent still reads as burn, removal or a
## sweeper. A card-local effect the reader cannot price declares its shape
## through [member EffectBase.ai_role] for the Stage 4 policy.
## Targeting restrictions live in the TargetSpec, never in resolve().
##
## - Two slots stated against each other (Deadshot's "another target
##   creature", Legerdemain's "another target permanent that shares one of
##   those types with it") are a sibling filter on the second slot; the
##   effect that does the work re-judges the FIRST slot itself, since the
##   engine only drops an illegal ref from its own effect (CR 608.2b: an
##   illegal target is neither affected nor made to act).
## - Reckless Spite's "two target nonblack creatures" is ONE effect taking
##   two refs (two different objects, CR 601.2c); the life loss is
##   untargeted, so it happens unless both targets are gone (CR 608.2b).
## - Interdict counts its permanent by the ability's SOURCE: on the
##   battlefield its live types, gone (sacrificed as a cost) its last-known
##   printed types; an ability activated from a graveyard is a card's, not
##   a permanent's (CR 109.2), and is no legal target. The activation ban
##   binds that permanent's battlefield incarnation (CR 400.7) and covers
##   its mana abilities too — they are activated abilities.
## - Stun's "can't block this turn" is a floating static bound to the
##   creature (forgotten if it leaves, CR 400.7), expiring at cleanup.
## - Blood Frenzy's destruction is the engine's end-step doom: unconditional,
##   a destroy (not a sacrifice), bound to that battlefield incarnation.
## tests/cards/test_pack_9_B6_spells.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Gallantry":
			var gallant := PumpEffect.new(4, 4)
			gallant.target_spec = TargetSpec.creature("target blocking creature") \
				.with_game_filter(P.blocking).because(TargetSpec.WHY["blocking"])
			c.spell(gallant).spell(DrawEffect.new(1))
		"Repentance": c.spell(Repentance.new())
		"Serene Offering": c.spell(SereneOffering.new())
		"Winds of Rath": c.spell(WindsOfRath.new())
		# ------------------------------------------------------------- blue
		"Dismiss": c.spell(CounterEffect.new()).spell(DrawEffect.new(1))
		"Interdict": c.spell(Interdict.new()).spell(DrawEffect.new(1))
		"Legerdemain":
			var give := LegerSlot.new()
			c.spell(give).spell(LegerSwap.new(give.target_spec))
		"Meditate":
			c.spell(DrawEffect.new(4))
			c.spell(F.Action.new(_skip_turn, "you skip your next turn").with_ai_role(&"skip_next_turn"))
		"Time Warp": c.spell(TimeWarp.new())
		"Twitch": c.spell(TapOrUntap.new()).spell(DrawEffect.new(1))
		# ------------------------------------------------------------ black
		"Diabolic Edict": c.spell(Edict.new())
		"Dregs of Sorrow":
			var dregs := DestroyEffect.new(TargetSpec.creature("X target nonblack creatures", P.nonblack))
			dregs.x_targets()
			c.spell(dregs).spell(DrawX.new())
		"Perish": c.spell(DestroyAllEffect.new("all green creatures", P.green_creature, false))
		"Reanimate": c.spell(Reanimation.new())
		"Reckless Spite":
			var spite := DestroyEffect.new(TargetSpec.creature("two target nonblack creatures", P.nonblack))
			spite.target_min = 2
			spite.target_max = 2
			c.spell(spite).spell(GainLifeEffect.new(-5))
		# -------------------------------------------------------------- red
		"Aftershock":
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target artifact, creature, or land", P.artifact_creature_or_land)))
			c.spell(SelfDamage.new(3))
		"Apocalypse":
			c.spell(F.Action.new(_apocalypse, "exile all permanents; you discard your hand") \
				.with_ai_role(&"exile_all_permanents_discard_hand"))
		"Blood Frenzy":
			c.castable_only_when(_before_combat_damage)
			c.spell(BloodFrenzy.new())
		"Boil": c.spell(DestroyAllEffect.new("all Islands", P.island))
		"Deadshot":
			var tap := TapEffect.new(TargetSpec.creature())
			c.spell(tap).spell(DeadshotShot.new(tap.target_spec))
		"Kindle": c.spell(Kindle.new())
		"Lightning Blast": c.spell(DamageEffect.new(4).any_target())
		"Rolling Thunder": c.spell(DamageEffect.new(0).any_target().x_damage().divided(-1))
		"Stun":
			c.spell(F.Action.new(_stun, "target creature can't block this turn", TargetSpec.creature()) \
				.with_ai_role(&"cant_block_this_turn"))
			c.spell(DrawEffect.new(1))
		"Sudden Impact": c.spell(SuddenImpact.new())
		# ------------------------------------------------------------ green
		"Overrun":
			c.spell(MassPumpEffect.new(3, 3, "creatures you control", [Mtg.Keyword.TRAMPLE]).yours_only())
		"Respite": c.spell(PreventCombatDamageEffect.new()).spell(LifePerAttacker.new())
		"Verdigris": c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", P.artifact)))
		_: return false
	return true


# ================================================================ predicates

## Instance tests read LIVE characteristics (cur_*), never printed data.
class P:
	static func color(i: CardInstance, mask: int) -> bool: return (i.cur_colors & mask) != 0
	static func nonblack(i: CardInstance) -> bool: return not color(i, Mtg.ManaColor.B)
	static func green_creature(i: CardInstance) -> bool: return i.is_creature() and color(i, Mtg.ManaColor.G)
	static func artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
	static func enchantment(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ENCHANTMENT)
	static func artifact_or_creature(i: CardInstance) -> bool:
		return i.is_type(Mtg.CardType.ARTIFACT) or i.is_creature()
	static func artifact_creature_or_land(i: CardInstance) -> bool:
		return i.is_type(Mtg.CardType.ARTIFACT) or i.is_creature() or i.is_land()
	## "Islands": a land with the Island subtype, read live (a Phantasmal
	## Terrain'd land is one, CR 305.7).
	static func island(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("island")
	## For the AI's sweep reading only (it has no game to ask): a creature
	## with nothing attached. The spell itself asks MtgGame.is_enchanted.
	static func bare_creature(i: CardInstance) -> bool: return i.is_creature() and i.attachments.is_empty()
	static func blocking(g: MtgGame, i: CardInstance) -> bool:
		return not g.combat.attackers_blocked_by(i.id).is_empty()
	static func attacking_or_blocking(g: MtgGame, i: CardInstance) -> bool:
		return g.combat.attackers.has(i.id) or blocking(g, i)

	## "Another target …": a different object from every earlier slot
	## (CR 115.3 — this text says so).
	static func distinct(_g: MtgGame, _s: CardInstance, candidate: TargetRef, earlier: Array) -> bool:
		for ref in earlier:
			if ref != null and ref.same_object(candidate):
				return false
		return true


# ============================================================ white classes

## Repentance: the creature is the SOURCE of the damage and its own
## recipient (CR 120.1). Power read as it resolves; 0 or less deals none.
class Repentance extends DamageEffect:
	func _init() -> void:
		super(0)
		target_creature()
		with_ai_role(&"self_power_damage")   # the AI's shape (Pack 9 stage 4)
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i):
			return
		if i.cur_power > 0:
			g.deal_damage(i, TargetRef.card(i), i.cur_power)
	func describe() -> String:
		return "target creature deals damage to itself equal to its power"


## Serene Offering: the life is the enchantment's mana value, read before it
## goes; the gain is a separate instruction and happens even when the
## destruction does not (an indestructible or regenerated target —
## Divine Offering's shape, leg/divine_offering.gd).
class SereneOffering extends DestroyEffect:
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment", P.enchantment))
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null or i.zone != Mtg.Zone.BATTLEFIELD:
			return
		var mv := i.data.cost.mana_value()
		g.destroy(i)
		g.adjust_life(pid, mv)
	func describe() -> String:
		return "destroy target enchantment; you gain life equal to its mana value"


## Winds of Rath: "creatures that aren't enchanted" — no Aura on the
## battlefield attached to it (MtgGame.is_enchanted), judged once, before
## anything is destroyed; all of them in one event, no regeneration.
class WindsOfRath extends DestroyAllEffect:
	func _init() -> void:
		super("all creatures that aren't enchanted", P.bare_creature, false)
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var victims: Array[CardInstance] = []
		for i in g.all_battlefield():
			if i.is_creature() and g.is_present(i) and not g.is_enchanted(i):
				victims.append(i)
		g.begin_simultaneous()
		for i in victims:
			g.destroy(i, false)
		g.end_simultaneous()


# ============================================================= blue classes

## Interdict's target: an activated ability whose source is an artifact,
## creature, enchantment, or land PERMANENT (see the module header).
class Interdict extends CounterAbilityEffect:
	const KINDS := Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE \
		| Mtg.CardType.ENCHANTMENT | Mtg.CardType.LAND
	func _init() -> void:
		super("target activated ability from an artifact, creature, enchantment, or land",
			Interdict.from_a_permanent)
	static func from_a_permanent(item: StackItem) -> bool:
		var card := item.card
		if card == null:
			return false
		if card.zone == Mtg.Zone.BATTLEFIELD:
			return (card.cur_types & KINDS) != 0
		# Activated where it lies now, in a graveyard: a card's ability.
		if card.zone == Mtg.Zone.GRAVEYARD \
				and card.graveyard_entry == int(item.cost_paid.get("_source_graveyard_entry", -1)):
			return false
		return (card.data.types & KINDS) != 0
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var item := g.find_stack_ability(t.ability_id)
		if item == null:
			return
		var source := item.card
		g.counter_ability(t.ability_id)
		if source == null or not g.is_present(source):
			return   # "that permanent" is gone: nothing to ban
		g.add_floating_activation_ban(-1, Interdict._banned.bind(source.id, source.layer_timestamp),
			"Interdict: %s" % source.data.card_name)
	static func _banned(_g: MtgGame, _pid: int, inst: CardInstance, _ability: Variant,
			_is_mana: bool, id: int, stamp: int) -> bool:
		return inst != null and inst.id == id and inst.layer_timestamp == stamp
	func describe() -> String:
		return "counter target activated ability from an artifact, creature, enchantment, or land; that permanent's activated abilities can't be activated this turn"


## Legerdemain, slot 1: the artifact or creature. It does nothing itself;
## LegerSwap trades it.
class LegerSlot extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact or creature",
			P.artifact_or_creature)
	func resolve(_g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		pass
	func describe() -> String:
		return "the artifact or creature to exchange"


## Legerdemain, slot 2 and the exchange (CR 701.10): "another target
## permanent that shares one of those types with it" — artifact or
## creature, the ones the first slot names. Both must still be legal, and
## still share a type, or nothing is exchanged (CR 608.2b); the trade lasts
## indefinitely (MtgGame.exchange_control).
class LegerSwap extends EffectBase:
	var first_spec: TargetSpec
	func _init(first: TargetSpec) -> void:
		first_spec = first
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"another target permanent that shares one of those types with it", P.artifact_or_creature) \
			.with_sibling_filter(LegerSwap.shares_a_type, TargetSpec.WHY["type"])
	static func shares_a_type(g: MtgGame, _s: CardInstance, candidate: TargetRef, earlier: Array) -> bool:
		if earlier.is_empty() or earlier[0] == null or candidate.is_player:
			return false
		var first: TargetRef = earlier[0]
		if first.is_player or first.same_object(candidate):
			return false
		var a := g.find_instance(first.instance_id)
		var b := g.find_instance(candidate.instance_id)
		if a == null or b == null:
			return false
		return (a.is_type(Mtg.CardType.ARTIFACT) and b.is_type(Mtg.CardType.ARTIFACT)) \
			or (a.is_creature() and b.is_creature())
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var refs := g.current_targets()
		if refs.size() < 2 or refs[0] == null or t == null:
			return
		if not first_spec.is_legal(g, refs[0], s, [], pid):
			g.log_line("Legerdemain: the first target is no longer legal; nothing is exchanged")
			return
		g.exchange_control(g.find_instance(refs[0].instance_id), g.find_instance(t.instance_id))
	func describe() -> String:
		return "exchange control of target artifact or creature and another target permanent that shares one of those types with it"


static func _skip_turn(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.skip_next_turn(pid)


## Time Warp: the TARGET player takes the turn (CR 500.7, most recent first).
class TimeWarp extends ExtraTurnEffect:
	func _init() -> void:
		target_spec = TargetSpec.player()
		ai_helpful = true
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		g.add_extra_turn(t.player_id)
		g.log_line("%s will take an extra turn" % g.players[t.player_id].player_name)
	func describe() -> String:
		return "target player takes an extra turn after this one"


## Twitch's "you may tap or untap": three answers, the last one declining.
## Hint: untap our own tapped permanent, tap theirs, else leave it.
class TapOrUntap extends TapEffect:
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact, creature, or land",
			P.artifact_creature_or_land))
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null or i.zone != Mtg.Zone.BATTLEFIELD:
			return
		var labels: Array[String] = ["Tap it", "Untap it", "Leave it as it is"]
		var hint := 2
		if i.controller_id == pid and i.tapped: hint = 1
		elif i.controller_id != pid and not i.tapped: hint = 0
		match g.agents[pid].choose_option(g, pid, labels, "Twitch: tap or untap %s?" % i.data.card_name, hint):
			0: g.tap_permanent(i)
			1: g.untap_permanent(i)
	func describe() -> String:
		return "you may tap or untap target artifact, creature, or land"


# ============================================================ black classes

## Diabolic Edict: the TARGET player picks which of their creatures goes
## (offered weakest first — their own sensible answer, said so with
## `ordered`). Cruel Edict's AI shape (p02/_simple.gd).
class Edict extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()
		with_ai_role(&"opponent_sacrifice_creature")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var who := t.player_id
		var choices: Array[CardInstance] = []
		for i in g.players[who].creatures():
			if g.is_present(i): choices.append(i)
		if choices.is_empty():
			return
		choices.sort_custom(Edict._weakest_first)
		var pick := g.agents[who].choose_card(g, who, choices, "Diabolic Edict: choose a creature to sacrifice",
			false, false, true)
		if pick == null or not choices.has(pick): pick = choices[0]
		g.sacrifice_permanent(pick)
	static func _weakest_first(a: CardInstance, b: CardInstance) -> bool:
		var wa := a.data.cost.mana_value() + maxi(a.cur_power, 0) + maxi(a.cur_toughness, 0)
		var wb := b.data.cost.mana_value() + maxi(b.cur_power, 0) + maxi(b.cur_toughness, 0)
		if wa != wb: return wa < wb
		return a.id < b.id
	func describe() -> String:
		return "target player sacrifices a creature of their choice"


## "Draw X cards" (Dregs of Sorrow): the spell's X, whatever the
## destruction did.
class DrawX extends DrawEffect:
	func _init() -> void:
		super(0)
		x_cards()
	func describe() -> String:
		return "draw X cards"


## Reanimate: any graveyard's creature card, under the caster's control,
## and the life loss is its mana value as a card (X is 0 off the stack,
## CR 202.3e) — lost whether or not it stayed on the battlefield.
class Reanimation extends ReturnFromGraveyardEffect:
	func _init() -> void:
		super()
		target_spec = TargetSpec.new(TargetSpec.Kind.CREATURE_IN_ANY_GRAVEYARD)
		to_battlefield()
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null or i.zone != Mtg.Zone.GRAVEYARD:
			return
		var mv := i.data.cost.mana_value()
		g.reanimate(i, pid)
		g.adjust_life(pid, -mv)
	func describe() -> String:
		return "put target creature card from a graveyard onto the battlefield under your control; you lose life equal to its mana value"


# ============================================================== red classes

## "<This spell> deals N damage to you" — its caster, the spell the source.
class SelfDamage extends DamageEffect:
	func _init(n: int) -> void:
		super(n)
		to_controller()
	func describe() -> String:
		return "deals %d damage to you" % amount


## Exile every permanent (a phased-out one is treated as though it does not
## exist, CR 702.26b) in one event, then the caster discards their hand.
static func _apocalypse(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var doomed: Array[CardInstance] = []
	for i in g.all_battlefield():
		if g.is_present(i): doomed.append(i)
	g.begin_simultaneous()
	for i in doomed:
		if i.zone == Mtg.Zone.BATTLEFIELD: g.exile_permanent(i)
	g.end_simultaneous()
	g.discard_hand(pid)


## A combat damage step still ahead this turn — Berserk's reading
## (2ed/berserk.gd): an extra combat makes the second main phase "before".
static func _before_combat_damage(g: MtgGame, _pid: int) -> String:
	if not g.step_is_ahead(Mtg.Step.COMBAT_DAMAGE):
		return "Cast this spell only before the combat damage step"
	return ""


## Blood Frenzy: +4/+0 now, destroyed at the beginning of the next end step
## whatever happens in combat. Card-local — the pump reader would hand it to
## our own attacker and the removal reader to theirs, and both halves
## matter — so it declares its shape (`pump_doomed`) for the Stage 4 AI.
class BloodFrenzy extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("target attacking or blocking creature") \
			.with_game_filter(P.attacking_or_blocking).because(TargetSpec.WHY["attacking_blocking"])
		with_ai_role(&"pump_doomed", {"power": 4, "toughness": 0})
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i):
			return
		g.continuous.add_until_eot_pump(i.id, 4, 0, [])
		g.recalculate()
		g.log_line("%s gives %s +4/+0; it will be destroyed at the next end step" % [
			s.data.card_name, i.data.card_name])
		g.doom_at_next_end_step(i)
	func describe() -> String:
		return "target attacking or blocking creature gets +4/+0 until end of turn; destroy it at the beginning of the next end step"


## Deadshot's second slot and the shot: the first target, if it is still
## legal and present, deals damage equal to its power (as it resolves —
## it was tapped first) to this one.
class DeadshotShot extends DamageEffect:
	var first_spec: TargetSpec
	func _init(first: TargetSpec) -> void:
		super(0)
		first_spec = first
		target_spec = TargetSpec.creature("another target creature") \
			.with_sibling_filter(P.distinct, TargetSpec.WHY["cant_target"])
		with_ai_role(&"shooter_power_damage")   # the AI's shape (Pack 9 stage 4)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var refs := g.current_targets()
		if refs.is_empty() or refs[0] == null or t == null:
			return
		if not first_spec.is_legal(g, refs[0], s, [], pid):
			return   # an illegal first target is made to do nothing (CR 608.2b)
		var shooter := g.find_instance(refs[0].instance_id)
		if not g.is_present(shooter) or shooter.cur_power <= 0:
			return
		g.deal_damage(shooter, t, shooter.cur_power)
	func describe() -> String:
		return "the first creature deals damage equal to its power to another target creature"


## Kindle: 2 plus the cards named Kindle in ALL graveyards, counted as it
## resolves (this one is still on the stack). The AI reads the floor, 2.
class Kindle extends DamageEffect:
	func _init() -> void:
		super(2)
		any_target()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var n := 2
		for p in g.players:
			for card in p.graveyard:
				if card.data.card_name == "Kindle": n += 1
		g.deal_damage(s, t, n)
	func describe() -> String:
		return "deals X damage to any target, where X is 2 plus the number of cards named Kindle in all graveyards"


## Stun: a floating "can't block" bound to the creature (Panic's shape).
static func _stun(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	if not g.is_present(i):
		return
	g.continuous.add_floating_static(s, StaticAbility.new(_no_block.bind(i.id, i.layer_timestamp),
		"Can't block this turn."), ContinuousEffects.Duration.END_OF_TURN, -1, false, i.id)
	g.recalculate()

static func _no_block(g: MtgGame, _s: CardInstance, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == stamp:
		i.cur_cant_block_filter = _every_attacker

static func _every_attacker(_attacker: CardInstance) -> bool:
	return true


## Sudden Impact: the TARGET player's hand size as it resolves.
class SuddenImpact extends DamageEffect:
	func _init() -> void:
		super(0)
		target_player()
		with_ai_role(&"damage_per_hand_card")   # the AI's shape (Pack 9 stage 4)
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var n := g.players[t.player_id].hand.size()
		if n > 0:
			g.deal_damage(s, t, n)
	func describe() -> String:
		return "deals damage to target player equal to the number of cards in that player's hand"


# ============================================================ green classes

## Respite's second sentence: each creature still attacking as it resolves
## (removed or departed attackers are not counted, CR 506.4). The rider of
## a Fog, so the whole spell stays one of the 1997 damage-prevention
## window's family (`Duel.hlp`: "prevent, heal, or redirect damage") — the
## window admits a spell only when every effect is (Fighting Chance's
## reading, exo/_spells.gd).
class LifePerAttacker extends GainLifeEffect:
	func _init() -> void:
		super(0)
		is_damage_prevention = true
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var n := 0
		for id in g.combat.attackers:
			var i := g.find_instance(id)
			if g.is_present(i) and i.is_creature(): n += 1
		if n > 0:
			g.adjust_life(pid, n)
	func describe() -> String:
		return "you gain 1 life for each attacking creature"
