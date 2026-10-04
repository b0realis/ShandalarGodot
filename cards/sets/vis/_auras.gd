extends RefCounted
## Visions (_auras, Pack 8). Auras and their enchanted-permanent effects.
##
## The shared helpers and host effects live in cards/sets/mir/_auras.gd
## (A): host lookups, trigger host capture, HostPump / HostBounce /
## HostRegenerate (each resolves on the creature the Aura enchanted when
## its ability was activated — so a sacrificed Aura still knows it).
##
## Parapet, Relic Ward, Mystic Veil and Spider Climb carry the Mirage
## flash rider (CardData.with_flash_rider — the CR 514.3a cleanup
## sacrifice is the engine's).
## Betrayal: "Enchant creature an opponent controls" is a source-relative
##   requirement on the Aura spell's target (TargetSpec.with_source_filter).
## Mob Mentality: "Whenever all non-Wall creatures you control attack" — a
##   DECLARED_ATTACKERS trigger of the Aura's controller's attack in which
##   every non-Wall creature they control is attacking (at least one);
##   X is the number of attacking creatures as the ability resolves
##   (CR 608.2h).
## Vampirism: "you" is the AURA's controller in both statics; "other" means
##   other than the enchanted creature.
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/mir/_auras.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Parapet":
			c.with_flash_rider()
			c.static_ability(StaticAbility.new(_parapet, "Creatures you control get +0/+1."))
		"Relic Ward":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _artifact)).with_flash_rider()
			c.static_ability(StaticAbility.new(_host_shroud, "Enchanted artifact has shroud.").changing_abilities())
		"Sun Clasp":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 3), "Enchanted creature gets +1/+3."))
			c.activated(ActivatedAbility.new("{W}", false, [A.HostBounce.new()],
				"{W}: Return enchanted creature to its owner's hand."))
		"Betrayal":
			c.enchants(TargetSpec.creature("target creature an opponent controls").with_source_filter(_opponents).because("controller"))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TAPPED, _betrayal_draw,
				"Whenever enchanted creature becomes tapped, you draw a card.", _host_tapped))
		"Mystic Veil":
			c.enchants(TargetSpec.creature()).with_flash_rider()
			c.static_ability(StaticAbility.new(_host_shroud, "Enchanted creature has shroud.").changing_abilities())
		"Dark Privilege":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 1), "Enchanted creature gets +1/+1."))
			c.activated(ActivatedAbility.new("", false, [A.HostRegenerate.new()],
				"Sacrifice a creature: Regenerate enchanted creature.").with_sacrifice_of("creature", _creature))
		"Death Watch":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _death_watch,
				"When enchanted creature dies, its controller loses life equal to its power and you gain life equal to its toughness.",
				A.host_died))
		"Vampirism":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, A.slow_draw,
				"When this Aura enters, draw a card at the beginning of the next turn's upkeep.", F._self_enter))
			c.static_ability(StaticAbility.new(_vampirism_pump, "Enchanted creature gets +1/+1 for each other creature you control."))
			c.static_ability(StaticAbility.new(_vampirism_drain, "Other creatures you control get -1/-1."))
		"Mob Mentality":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.TRAMPLE]),
				"Enchanted creature has trample.").changing_abilities())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _mob_pump,
				"Whenever all non-Wall creatures you control attack, enchanted creature gets +X/+0 until end of turn, where X is the number of attacking creatures.",
				_mob_attacks).capturing(A.host_context))
		"Mortal Wound":
			c.enchants(TargetSpec.creature())
			# The victim's event: one per damage event (CR 510.2).
			c.triggered(TriggeredAbility.new(Mtg.EventType.WAS_DEALT_DAMAGE, _mortal_wound,
				"When enchanted creature is dealt damage, destroy it.", A.host_dealt_damage).capturing(A.host_context))
		"Spider Climb":
			c.enchants(TargetSpec.creature()).with_flash_rider()
			c.static_ability(StaticAbility.new(F._aura_pump.bind(0, 3), "Enchanted creature gets +0/+3."))
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.REACH]),
				"Enchanted creature has reach.").changing_abilities())
		_: return false
	return true


static func _artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _opponents(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s != null and i.controller_id != g.controller_acting_for(s)

static func _host_shroud(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i != null: i.cur_shroud = true


# ------------------------------------------------------------------- Parapet --

static func _parapet(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature() and not i.phased_out: i.cur_toughness += 1


# ------------------------------------------------------------------ Betrayal --

static func _host_tapped(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var tapped: CardInstance = e.data.get("instance")
	return tapped != null and tapped.id == s.attached_to

static func _betrayal_draw(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(A.pid_of(g, s), 1)


# --------------------------------------------------------------- Death Watch --

## Last known information (CR 608.2h): the power and toughness the creature
## had as it died; its controller then, the Aura's controller "you".
static func _death_watch(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var dead: CardInstance = e.data.get("instance")
	g.adjust_life(int(e.data.get("controller", dead.controller_id)), -maxi(dead.last_power, 0))
	g.adjust_life(A.pid_of(g, s), maxi(dead.last_toughness, 0))


# ----------------------------------------------------------------- Vampirism --

static func _vampirism_pump(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null: return
	var others := 0
	for other in g.players[s.controller_id].battlefield:
		if other != i and other.is_creature() and not other.phased_out: others += 1
	i.cur_power += others
	i.cur_toughness += others

static func _vampirism_drain(g: MtgGame, s: CardInstance) -> void:
	var host := A.host(g, s)
	for other in g.players[s.controller_id].battlefield:
		if other != host and other.is_creature() and not other.phased_out:
			other.cur_power -= 1
			other.cur_toughness -= 1


# ------------------------------------------------------------- Mob Mentality --

static func _mob_attacks(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var attackers: Array = e.data.get("attackers", [])
	if attackers.is_empty() or g.active_player != s.controller_id or A.host(g, s) == null: return false
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature() and not i.phased_out and not i.has_subtype("wall") and not attackers.has(i):
			return false
	return true

static func _mob_pump(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := A.trigger_host(g, s)
	var x := 0
	for id in g.combat.attackers:
		if g.is_present(g.find_instance(int(id))): x += 1
	if i == null or x <= 0: return
	g.continuous.add_until_eot_pump(i.id, x, 0, [])
	g.log_line("%s gives %s +%d/+0 until end of turn" % [s.data.card_name, i.data.card_name, x], s)
	g.recalculate()


# -------------------------------------------------------------- Mortal Wound --

static func _mortal_wound(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := A.trigger_host(g, s)
	if i != null: g.destroy(i)
