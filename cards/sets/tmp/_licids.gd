extends RefCounted
## Tempest (_licids, Pack 9). Licids: creatures that become Auras attached
## to a creature until their controller pays to end the effect.
##
## Conventions (sth/_licids.gd and exo/_licids.gd follow them):
## - The licid ability is Pack 9 E3's CardData.as_licid(activation, end):
##   "<activation>, {T}: This creature loses this ability and becomes an
##   Aura enchantment with enchant creature. Attach it to target creature.
##   You may pay <end> to end this effect." It is built FIRST, so it is
##   ability 0. Becoming an Aura is an instance-level identity swap with no
##   zone change (MtgGame.become_licid_aura); "pay <end>" is a special
##   action (MtgGame.end_licid_effect, listed by MtgGame.special_actions,
##   CR 116.2c) that makes it its creature self again where it stands.
##   enchants() is never called: the printed card is a creature.
## - Every OTHER line is written exactly as the same line on a real Aura,
##   keyed to the licid's `attached_to` (cards/sets/mir/_auras.gd host
##   lookups): while the licid is a creature it enchants nothing and the
##   line does nothing; as an Aura it works. A trigger names "enchanted
##   creature" as it was when the ability triggered (mir/_auras.gd
##   host_context) and finds it again only while it is the same object
##   (CR 400.7).
## - Volrath's Curse shares E3's other special action — "That creature's
##   controller may sacrifice a permanent of their choice for that player
##   to ignore this effect until end of turn" (CardData.ignorable_by_sacrifice,
##   MtgGame.ignore_static_effect, CR 116.2d). Its three bans each ask
##   MtgGame.effect_ignored_by for the player concerned: the enchanted
##   creature's controller for "can't attack or block", the activating
##   player for "its activated abilities can't be activated" — mana
##   abilities included, which are activated abilities (CR 605.1a).
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/mir/_auras.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Enraging Licid":
			c.as_licid("{R}", "{R}")
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.HASTE]),
				"Enchanted creature has haste.").changing_abilities())
		"Leeching Licid":
			c.as_licid("{B}", "{B}")
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _leech,
				"At the beginning of the upkeep of enchanted creature's controller, this creature deals 1 damage to that player.",
				host_upkeep).capturing(A.host_context))
		"Nurturing Licid":
			c.as_licid("{G}", "{G}")
			var regenerate := F.Action.new(_nurture, "regenerate enchanted creature", null, true)
			regenerate.is_regeneration = true
			regenerate.with_ai_role(&"regenerate_host")
			c.activated(ActivatedAbility.new("{G}", false, [regenerate], "{G}: Regenerate enchanted creature."))
		"Quickening Licid":
			c.as_licid("{1}{W}", "{W}")
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FIRST_STRIKE]),
				"Enchanted creature has first strike.").changing_abilities())
		"Stinging Licid":
			c.as_licid("{1}{U}", "{U}")
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TAPPED, _sting,
				"Whenever enchanted creature becomes tapped, this creature deals 2 damage to that creature's controller.",
				host_tapped).capturing(A.host_context))
		"Volrath's Curse":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_curse_host, "Enchanted creature can't attack or block."))
			c.bans_activations(_curse_ban)
			c.ignorable_by_sacrifice("permanent")
			c.activated(ActivatedAbility.new("{1}{U}", false,
				[F.Action.new(_curse_home, "return this Aura to its owner's hand", null, false) \
					.with_ai_role(&"return_self_to_hand")],
				"{1}{U}: Return this Aura to its owner's hand."))
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

## "At the beginning of the upkeep of enchanted creature's controller".
static func host_upkeep(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i := A.host(g, s)
	return i != null and i.controller_id == int(e.data.get("player", -1))

## "Whenever enchanted creature becomes tapped".
static func host_tapped(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i := A.host(g, s)
	return i != null and e.data.get("instance") == i

static func _anything(_i: CardInstance) -> bool:
	return true


# ------------------------------------------------------------ Leeching Licid --

## "That player" is the one whose upkeep it is: the host's controller when
## the ability triggered. The damage comes from the licid, from its last
## known information if it has gone (CR 608.2h).
static func _leech(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).get("host_controller", -1))
	if pid >= 0:
		g.deal_damage(s, TargetRef.player(pid), 1)


# ----------------------------------------------------------- Nurturing Licid --

## "Regenerate enchanted creature": the creature the licid enchants as the
## ability resolves (CR 608.2b). If its effect was ended in response it
## enchants nothing and nothing is regenerated; if the licid has left the
## battlefield, the creature it enchanted as it last existed (CR 608.2h).
static func _nurture(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var host: CardInstance = null
	if s.zone == Mtg.Zone.BATTLEFIELD \
			and s.layer_timestamp == int(g.cost_paid("_source_timestamp", s.layer_timestamp)):
		host = A.host(g, s)
	else:
		var last := g.find_instance(int(g.cost_paid("_source_attached_to", -1)))
		if g.is_present(last) and last.layer_timestamp == int(g.cost_paid("_source_attached_timestamp", -2)):
			host = last
	if host != null and host.is_creature():
		RegenerateEffect.new().target_creature().resolve(g, s, pid, TargetRef.card(host))


# ------------------------------------------------------------ Stinging Licid --

## "That creature's controller": the creature's controller now if it is
## still the same object, else as it last existed (CR 608.2h).
static func _sting(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var host := A.trigger_host(g, s)
	var pid := host.controller_id if host != null else int(g.trigger_context(s).get("host_controller", -1))
	if pid >= 0:
		g.deal_damage(s, TargetRef.player(pid), 2)


# ----------------------------------------------------------- Volrath's Curse --

static func _curse_host(g: MtgGame, s: CardInstance) -> void:
	var h := A.host(g, s)
	if h == null or g.effect_ignored_by(s, h.controller_id):
		return
	h.cur_cant_attack = true
	h.cur_cant_block_filter = _anything

static func _curse_ban(g: MtgGame, s: CardInstance, pid: int, inst: CardInstance,
		_ability: Variant, _is_mana: bool) -> bool:
	return s.attached_to != -1 and inst.id == s.attached_to and not g.effect_ignored_by(s, pid)

## "Return this Aura to its owner's hand" — only the object that activated
## it (CR 400.7), phased in (CR 702.26b).
static func _curse_home(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if F._same_activation_source(g, s):
		g.return_to_hand(s)
