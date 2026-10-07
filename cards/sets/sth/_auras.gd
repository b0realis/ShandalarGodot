extends RefCounted
## Stronghold (_auras, Pack 9). Auras and their enchanted-permanent effects.
##
## The shared helpers live in cards/sets/mir/_auras.gd (A): statics read the
## host through A.host (present, not phased out); an Aura's activated
## ability names the creature it enchanted when activated (A.HostPump); a
## granted ability is a layer-6 static (changing_abilities, CR 613.7).
##
## - Contempt: the attack trigger names the creature as it was when it
##   triggered (A.host_context); it creates ONE delayed trigger (CR 603.7)
##   at the end of combat returning that creature and this Aura, each only
##   if it is still that object (CR 400.7) — so a creature that died in
##   combat, or an Aura that already fell off, is not returned, and the
##   other one still is.
## - Overgrowth: a mana trigger (CR 605.1b) — the {G}{G} is added as the
##   land is tapped, to the land's controller.
## - Conviction's "{W}: Return this Aura to its owner's hand" declares the
##   `self_bounce` role: the AI saves it in response to a spell aimed at it.
## - Samite Blessing grants its creature an activated ability; the source
##   is chosen as the ability resolves (CR 609.7a) and the shield is one
##   entry of the damage suite used up by one damage event (CR 615.8). It
##   is a damage-prevention effect (legal in the 1997 window).
## tests/cards/test_pack_9_B10_auras.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/mir/_auras.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Contempt":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _contempt,
				"When enchanted creature attacks, return it and this Aura to their owners' hands at end of combat.",
				_host_attacks).capturing(A.host_context))
		"Conviction":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 3), "Enchanted creature gets +1/+3."))
			c.activated(ActivatedAbility.new("{W}", false,
				[F.Action.new(_home, "return this Aura to its owner's hand").with_ai_role(&"self_bounce")],
				"{W}: Return this Aura to its owner's hand."))
		"Flowstone Blade":
			c.enchants(TargetSpec.creature())
			c.activated(ActivatedAbility.new("{R}", false, [A.HostPump.new(1, -1)],
				"{R}: Enchanted creature gets +1/-1 until end of turn."))
		"Overgrowth":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land))
			var bonus := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _overgrowth,
				"Whenever enchanted land is tapped for mana, its controller adds an additional {G}{G}.",
				_host_tapped).as_mana_trigger()
			# The planner's public description (ManaPlanner._bonus_triggers).
			bonus.mana_bonus_subtype = ManaPlanner.BONUS_ENCHANTED_LAND
			bonus.mana_bonus_color = Mtg.ManaColor.G
			bonus.mana_bonus_amount = 2
			c.triggered(bonus)
		"Samite Blessing":
			c.enchants(TargetSpec.creature())
			var blessing := ActivatedAbility.new("", true, [BlessingShield.new()],
				"{T}: The next time a source of your choice would deal damage to target creature this turn, prevent that damage.")
			c.static_ability(StaticAbility.new(A.grant_ability.bind(blessing),
				"Enchanted creature has \"{T}: The next time a source of your choice would deal damage to target creature this turn, prevent that damage.\"") \
				.changing_abilities())
		"Torment":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(-3, 0), "Enchanted creature gets -3/-0."))
		_: return false
	return true


static func _land(i: CardInstance) -> bool: return i.is_land()

static func _live(g: MtgGame, id: int, stamp: int) -> CardInstance:
	var i := g.find_instance(id)
	return i if g.is_present(i) and i.layer_timestamp == stamp else null


# ------------------------------------------------------------------ Contempt --

static func _host_attacks(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	if s.attached_to == -1: return false
	for i in e.data.get("attackers", []):
		if i != null and (i as CardInstance).id == s.attached_to: return true
	return false

static func _contempt(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var pid := int(ctx.get("controller", s.controller_id))
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT,
		_contempt_return.bind(int(ctx.get("host", -1)), int(ctx.get("host_stamp", -2)),
			s.id, int(ctx.get("timestamp", -2))),
		"Return it and this Aura to their owners' hands."), pid, s)

static func _contempt_return(g: MtgGame, _s: CardInstance, _e: GameEvent,
		host_id: int, host_stamp: int, aura_id: int, aura_stamp: int) -> void:
	var host := _live(g, host_id, host_stamp)
	var aura := _live(g, aura_id, aura_stamp)
	if host == null and aura == null: return
	g.begin_simultaneous()
	if host != null: g.return_to_hand(host)
	if aura != null and g.is_present(aura): g.return_to_hand(aura)
	g.end_simultaneous()


# ---------------------------------------------------------------- Conviction --

## "Return this Aura to its owner's hand" — only the object that activated
## it (CR 400.7); a phased-out one is treated as though it doesn't exist.
static func _home(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if F._same_activation_source(g, s): g.return_to_hand(s)


# ---------------------------------------------------------------- Overgrowth --

static func _host_tapped(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var land: CardInstance = e.data.get("instance")
	return s.attached_to != -1 and land != null and land.id == s.attached_to

static func _overgrowth(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var pid := int(e.data.get("controller", -1))
	if pid < 0: return
	g.players[pid].mana_pool.add(Mtg.ManaColor.G, 2)
	g.log_line("Overgrowth adds an additional {G}{G}")


# ----------------------------------------------------------- Samite Blessing --

## The granted ability's effect: its source is the enchanted creature. "A
## source of your choice" is named as it resolves; nothing to name, nothing
## happens (CR 608.2).
class BlessingShield extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()
		is_damage_prevention = true
		ai_helpful = true
		with_ai_role(&"source_shield")
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if t == null: return
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		var named := g.choose_damage_source(pid, "Samite Blessing: Select a source.", Callable(),
			TargetRef.card(i))
		if named == null:
			g.log_line("Samite Blessing: no source to name, nothing happens")
			return
		g.shield_next_damage(pid, "Samite Blessing", named, [TargetRef.card(i)])
		g.log_line("Samite Blessing: the next damage %s would deal to %s this turn is prevented" % [
			named.data.card_name, i.data.card_name])
	func describe() -> String:
		return "the next time a source of your choice would deal damage to target creature this turn, prevent that damage"
