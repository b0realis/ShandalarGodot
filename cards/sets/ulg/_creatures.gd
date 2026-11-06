extends RefCounted
## Urza's Legacy (_creatures, Pack 10). Creatures with activated, static or characteristic-defining abilities.
##
## Every listed name implements its whole Oracle text, with a typed effect
## wherever the vocabulary has one (the fair AI reads them —
## engine/ai/effect_intent.gd) and a declared role where an existing
## reading fits the shape (Fleeting Image's `self_bounce`, Mother of Runes'
## `protection`). tests/cards/test_pack_10_B4_*.gd pin each card's
## distinguishing clause and its edges.
##
## - PROTECTION FROM ARTIFACTS (Angelic Curator, Yavimaya Scion; CR 702.16)
##   is not a colour, so it is composed the way Artifact Ward composes its
##   three clauses (cards/sets/atq/artifact_ward.gd), on the creature itself
##   and as a layer-6 static (`changing_abilities`, so Humility takes it,
##   CR 613.1f): can't be Blocked by artifact creatures, Damage from
##   artifact sources is prevented, can't be Targeted by artifact spells or
##   abilities from artifact sources. The E of DEBT has nothing to do: the
##   pool has no artifact Aura or Equipment. A source that has left is read
##   as it last existed (MtgGame.source_types, CR 113.7a).
## - "Sacrifice this creature" abilities resolve from the creature as it
##   last existed (CR 608.2h): Ghitu Fire-Eater's power is its last power.
## - Goblin Welder's two targets are two slots — the artifact, then the
##   artifact card in its controller's graveyard (a sibling filter judged
##   at activation and again on resolution, CR 608.2b). "If both targets
##   are still legal" is all or nothing: the second slot's effect re-judges
##   the first and does the swap only when both stand; the sacrifice and
##   the return are one simultaneous event.
## - Molten Hydra's "remove all +1/+1 counters" is a COST (CR 118.3) —
##   tmp/_artifacts.gd's `_remove_all`, Essence Bottle's shape; Anthroplasm's
##   "remove all … and put X" is its EFFECT, done on resolution.
## - Multani is Maro's shape (mir/_creatures.gd): a base-P/T static plus the
##   same callable as the card's characteristic definition, so it counts in
##   every zone (CR 604.3); a hand change recalculates before the
##   state-based actions look at it.
const F := preload("res://cards/sets/fem/_rules.gd")
const MA := preload("res://cards/sets/mir/_artifacts.gd")
const MCR := preload("res://cards/sets/mir/_creatures.gd")
const MS := preload("res://cards/sets/mir/_spells.gd")
const TA := preload("res://cards/sets/tmp/_artifacts.gd")
const TC := preload("res://cards/sets/tmp/_creatures.gd")
const WC := preload("res://cards/sets/wth/_creatures.gd")

## Walking Sponge's three choices, in the printed order.
const SPONGE_KEYWORDS: Array[int] = [Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.TRAMPLE]
const SPONGE_LABELS: Array[String] = ["Flying", "First strike", "Trample"]
## Every colour protection can name (Mtg.ManaColor W|U|B|R|G): Mother of
## Runes' `protection` role watches a spell of any of them.
const COLOR_BITS := 31

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ---------------------------------------------------------- white
		"Angelic Curator", "Yavimaya Scion":
			# Angelic Curator's flying is the scaffold's.
			protection_from_artifacts(c)
		"Devout Harpist":
			c.activated(ActivatedAbility.new("", true,
				[DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
					"target Aura attached to a creature", _aura).with_game_filter(_on_a_creature))],
				"{T}: Destroy target Aura attached to a creature."))
		"Expendable Troops":
			# Sawback Manticore's "attacking or blocking" filter.
			var shot := DamageEffect.new(2).target_creature("target attacking or blocking creature")
			shot.target_spec.with_game_filter(MCR._in_combat).because(TargetSpec.WHY["attacking_blocking"])
			c.activated(ActivatedAbility.new("", true, [shot],
				"{T}, Sacrifice this creature: It deals 2 damage to target attacking or blocking creature.") \
				.with_sacrifice_cost())
		"Mother of Runes":
			# The colour is chosen as the ability resolves (CR 608.2d), Knight
			# of Dawn's question for a creature of yours; the hint
			# (TC._dawn_hint) names the colour of an opposing spell or ability
			# aimed at it. Role `protection` (engine/ai/homelands_tactics.gd)
			# over every colour: the fair AI's answer to a coloured opposing
			# spell that targets its creature.
			c.activated(ActivatedAbility.new("", true,
				[F.Action.new(_runes, "target creature you control gains protection from the color of your choice until end of turn",
					TargetSpec.creature("target creature you control").with_source_filter(_yours) \
						.because(TargetSpec.WHY["controller"]), true) \
					.with_ai_role(&"protection", {"color": COLOR_BITS})],
				"{T}: Target creature you control gains protection from the color of your choice until end of turn."))
		"Radiant, Archangel":
			# Flying and vigilance are the scaffold's. Untagged: the count runs
			# in the pass after layer 6, where flying is settled (CR 613.4c).
			c.static_ability(StaticAbility.new(_radiant,
				"Radiant gets +1/+1 for each other creature on the battlefield with flying."))
		"Tragic Poet":
			var verse := ReturnFromGraveyardEffect.new()
			verse.target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD,
				"target enchantment card from your graveyard", _enchantment_card)
			c.activated(ActivatedAbility.new("", true, [verse],
				"{T}, Sacrifice this creature: Return target enchantment card from your graveyard to your hand.") \
				.with_sacrifice_cost())
		# ----------------------------------------------------------- blue
		"Anthroplasm":
			c.with_enters_counters("+1/+1", 2)
			c.activated(ActivatedAbility.new("{X}", true,
				[F.Action.new(_anthroplasm, "remove all +1/+1 counters from this creature and put X +1/+1 counters on it", null, true)],
				"{X}, {T}: Remove all +1/+1 counters from this creature and put X +1/+1 counters on it."))
		"Archivist":
			c.activated(ActivatedAbility.new("", true, [DrawEffect.new(1)], "{T}: Draw a card."))
		"Bouncing Beebles":
			# "Defending player" is the opponent whenever it attacks (CR
			# 506.2, two players); outside combat the static changes nothing.
			c.static_ability(StaticAbility.new(_beebles,
				"This creature can't be blocked as long as defending player controls an artifact.").changing_abilities())
		"Fleeting Image":
			# The scaffold prints flying. Role `self_bounce` (Selenia's): the
			# fair AI's answer to an opposing spell aimed at it.
			c.activated(ActivatedAbility.new("{1}{U}", false,
				[F.Action.new(_fleeting, "return this creature to its owner's hand", null, true).with_ai_role(&"self_bounce")],
				"{1}{U}: Return this creature to its owner's hand."))
		"King Crab":
			c.activated(ActivatedAbility.new("{1}{U}", true,
				[MS.ToLibraryTop.new(TargetSpec.creature("target green creature", MCR._green).because(TargetSpec.WHY["color"]))],
				"{1}{U}, {T}: Put target green creature on top of its owner's library."))
		"Thornwind Faeries":
			c.activated(ActivatedAbility.new("", true, [DamageEffect.new(1).any_target()],
				"{T}: This creature deals 1 damage to any target."))
		"Walking Sponge":
			# The choice is made on resolution (CR 608.2d); the loss is the
			# pipeline's until-end-of-turn loss, applied after every grant.
			c.activated(ActivatedAbility.new("", true,
				[F.Action.new(_sponge, "target creature loses your choice of flying, first strike, or trample until end of turn",
					TargetSpec.creature())],
				"{T}: Target creature loses your choice of flying, first strike, or trample until end of turn."))
		# ---------------------------------------------------------- black
		"Fog of Gnats":
			c.activated(ActivatedAbility.new("{B}", false, [RegenerateEffect.new()], "{B}: Regenerate this creature."))
		"Phyrexian Broodlings":
			# Any creature you control, the Broodlings included (CR 701.17a);
			# the counter lands only on the object that paid (WC.SelfCounter).
			c.activated(ActivatedAbility.new("{1}", false, [WC.SelfCounter.new("+1/+1")],
				"{1}, Sacrifice a creature: Put a +1/+1 counter on this creature.") \
				.with_sacrifice_of("creature", F._creature).may_sacrifice_itself())
		"Phyrexian Debaser":
			c.activated(_carrier(2))
		"Phyrexian Defiler":
			c.activated(_carrier(3))
		"Phyrexian Denouncer":
			c.activated(_carrier(1))
		"Phyrexian Plaguelord":
			c.activated(_carrier(4))
			c.activated(ActivatedAbility.new("", false, [PumpEffect.new(-1, -1)],
				"Sacrifice a creature: Target creature gets -1/-1 until end of turn.") \
				.with_sacrifice_of("creature", F._creature).may_sacrifice_itself())
		# ------------------------------------------------------------ red
		"Ghitu Fire-Eater":
			c.activated(ActivatedAbility.new("", true, [PowerShot.new(2)],
				"{T}, Sacrifice this creature: It deals damage equal to its power to any target.").with_sacrifice_cost())
		"Goblin Welder":
			var slot := WeldSlot.new()
			c.activated(ActivatedAbility.new("", true, [slot, Weld.new(slot.target_spec)],
				"{T}: Choose target artifact a player controls and target artifact card in that player's graveyard. If both targets are still legal as this ability resolves, that player simultaneously sacrifices the artifact and returns the artifact card to the battlefield."))
		"Molten Hydra":
			c.activated(ActivatedAbility.new("{1}{R}{R}", false, [WC.SelfCounter.new("+1/+1")],
				"{1}{R}{R}: Put a +1/+1 counter on this creature."))
			var burst := ActivatedAbility.new("", true, [HydraBurst.new()],
				"{T}, Remove all +1/+1 counters from this creature: It deals damage to any target equal to the number of +1/+1 counters removed this way.")
			burst.on_cost_paid = TA._remove_all.bind("+1/+1")
			c.activated(burst)
		"Pygmy Pyrosaur":
			c.static_ability(StaticAbility.new(_cant_block, "This creature can't block."))
			c.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, 0).self_buff()],
				"{R}: This creature gets +1/+0 until end of turn."))
		"Viashino Heretic":
			c.activated(ActivatedAbility.new("{1}{R}", true, [HereticBlast.new()],
				"{1}{R}, {T}: Destroy target artifact. This creature deals damage to that artifact's controller equal to the artifact's mana value."))
		# ---------------------------------------------------------- green
		"Multani, Maro-Sorcerer":
			c.static_ability(StaticAbility.new(_shroud, "Shroud.").changing_abilities())
			c.static_ability(StaticAbility.new(_multani,
				"Multani's power and toughness are each equal to the total number of cards in all players' hands.").setting_base_pt())
			c.characteristic_definition = _multani
		"Weatherseed Elf":
			c.activated(ActivatedAbility.new("", true, [GrantLandwalkEffect.new(["forest"])],
				"{T}: Target creature gains forestwalk until end of turn."))
		_: return false
	return true


## "Protection from artifacts" on [param c] (see the header): one layer-6
## static carrying the B, D and T of DEBT.
static func protection_from_artifacts(c: CardData) -> void:
	c.static_ability(StaticAbility.new(_artifact_protection, "Protection from artifacts.").changing_abilities())


## "{T}, Sacrifice this creature: Target creature gets -N/-N until end of
## turn" — the Phyrexian Carriers.
static func _carrier(n: int) -> ActivatedAbility:
	return ActivatedAbility.new("", true, [PumpEffect.new(-n, -n)],
		"{T}, Sacrifice this creature: Target creature gets -%d/-%d until end of turn." % [n, n]).with_sacrifice_cost()


# ------------------------------------------------------------- filters --

static func _aura(i: CardInstance) -> bool:
	return i.is_aura()

## The Aura is attached to a creature on the battlefield (live types).
static func _on_a_creature(g: MtgGame, i: CardInstance) -> bool:
	var host := g.find_instance(i.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD and host.is_creature()

## A card in a graveyard has only its printed characteristics.
static func _enchantment_card(i: CardInstance) -> bool:
	return i.data.is_type(Mtg.CardType.ENCHANTMENT)

## "You control" is the activator's (CR 113.7a).
static func _yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s == null or i.controller_id == g.controller_acting_for(s)

static func _not_an_artifact(blocker: CardInstance) -> bool:
	return not blocker.is_type(Mtg.CardType.ARTIFACT)

static func _from_an_artifact(g: MtgGame, damage_source: CardInstance) -> bool:
	return damage_source != null and (g.source_types(damage_source) & Mtg.CardType.ARTIFACT) != 0

## Protection bans artifact SPELLS as well as abilities from artifact
## sources (CR 702.16b) — unlike Artifact Ward, which names abilities only.
static func _targeted_by_an_artifact(g: MtgGame, targeting: CardInstance, _spec: TargetSpec) -> bool:
	return targeting != null and (g.source_types(targeting) & Mtg.CardType.ARTIFACT) != 0


# -------------------------------------------------------------- statics --

static func _artifact_protection(_g: MtgGame, s: CardInstance) -> void:
	s.cur_block_restrictions.append({"desc": "creatures that aren't artifacts", "filter": _not_an_artifact})
	s.cur_damage_immunity.append({"desc": "protection from artifacts", "filter": _from_an_artifact})
	s.cur_target_bans.append({"desc": "protection from artifacts", "filter": _targeted_by_an_artifact})

static func _radiant(g: MtgGame, s: CardInstance) -> void:
	var n := 0
	for i in g.all_battlefield():
		if i != s and not i.phased_out and i.is_creature() and i.has_keyword(Mtg.Keyword.FLYING):
			n += 1
	s.cur_power += n
	s.cur_toughness += n

static func _beebles(g: MtgGame, s: CardInstance) -> void:
	if s.cur_keywords.has(Mtg.Keyword.UNBLOCKABLE):
		return
	for i in g.players[g.opponent_of(s.controller_id)].battlefield:
		if not i.phased_out and i.is_type(Mtg.CardType.ARTIFACT):
			s.cur_keywords.append(Mtg.Keyword.UNBLOCKABLE)
			return

static func _cant_block(_g: MtgGame, s: CardInstance) -> void:
	s.cur_cant_block_filter = _anything

static func _anything(_i: CardInstance) -> bool:
	return true

static func _shroud(_g: MtgGame, s: CardInstance) -> void:
	s.cur_shroud = true

## Every card in every hand, in whatever zone Multani is (CR 604.3).
static func _multani(g: MtgGame, s: CardInstance) -> void:
	var n := 0
	for p in g.players:
		n += p.hand.size()
	s.cur_power = n
	s.cur_toughness = n


# -------------------------------------------------------------- actions --

## Mother of Runes. The target is re-judged by the engine before this runs
## (CR 608.2b); the colour question goes to the activator.
static func _runes(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var host := g.find_instance(t.instance_id)
	if not g.is_present(host):
		return
	var hint := TC._dawn_hint(g, host, pid)
	var color := TC._first_color(g.agents[pid].choose_color(g, pid,
		"Mother of Runes: %s gains protection from which color?" % host.data.card_name, hint))
	if color == 0:
		color = hint
	g.continuous.add_until_eot_protection(host.id, color)
	g.recalculate()

## Anthroplasm: only the object that was tapped for it (CR 400.7). The
## removal and the new counters are one resolution: no state-based action
## sees the creature between them (CR 704.3).
static func _anthroplasm(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, x: int) -> void:
	if not MA.same_activation(g, s):
		return
	var had := int(s.counters.get("+1/+1", 0))
	if had > 0:
		g.remove_counters(s, "+1/+1", had)
	if x > 0:
		g.add_counters(s, "+1/+1", x)

static func _fleeting(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if MA.same_activation(g, s):
		g.return_to_hand(s)

## Walking Sponge. The hint: the first of the three the target has (an
## opposing flyer is grounded first), flying when it has none.
static func _sponge(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var victim := g.find_instance(t.instance_id)
	if not g.is_present(victim):
		return
	var hint := 0
	for index in SPONGE_KEYWORDS.size():
		if victim.has_keyword(SPONGE_KEYWORDS[index]):
			hint = index
			break
	var pick := g.agents[pid].choose_option(g, pid, SPONGE_LABELS,
		"Walking Sponge: %s loses which ability until end of turn?" % victim.data.card_name, hint)
	var lost: Array[int] = [SPONGE_KEYWORDS[clampi(pick, 0, SPONGE_KEYWORDS.size() - 1)]]
	g.continuous.add_until_eot_loss(victim.id, lost)
	g.recalculate()


# -------------------------------------------------------------- effects --

## Ghitu Fire-Eater: sacrificed as the cost, so "its power" is the power it
## had as it left (CR 608.2h); the printed power is what the AI reads.
class PowerShot extends DamageEffect:
	func _init(printed: int) -> void:
		super(printed)
		any_target()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var power := s.cur_power if s.zone == Mtg.Zone.BATTLEFIELD else s.last_power
		if power > 0:
			g.deal_damage(s, t, power)
	func describe() -> String:
		return "deals damage equal to its power to any target"


## Molten Hydra: the counters were removed as the cost; the count paid is
## the damage (0 deals none). By the Hydra as it last existed if it has
## left (CR 608.2h).
class HydraBurst extends DamageEffect:
	func _init() -> void:
		super(0)
		any_target()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var n := int(g.cost_paid("_counters_removed", 0))
		if n > 0:
			g.deal_damage(s, t, n)
	func describe() -> String:
		return "deals damage to any target equal to the number of +1/+1 counters removed this way"


## Viashino Heretic: the controller and the mana value are read before the
## destruction, and the damage is dealt whether or not the artifact was
## destroyed (a regeneration shield, indestructible) — the sentence does
## not depend on the first one. A DestroyEffect, so the AI reads removal.
class HereticBlast extends DestroyEffect:
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", MCR._artifact))
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i):
			return
		var who := i.controller_id
		var value := i.data.cost.mana_value()
		super.resolve(g, s, pid, t, x)
		if value > 0:
			g.deal_damage(s, TargetRef.player(who), value)
	func describe() -> String:
		return "destroy target artifact; this creature deals damage to its controller equal to its mana value"


## Goblin Welder, slot 1: the artifact on the battlefield. Holding the slot
## is this effect's whole job; [Weld] does the swap.
class WeldSlot extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact a player controls", MCR._artifact)
	func resolve(_g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		pass
	func describe() -> String:
		return "the artifact that player sacrifices"


## Goblin Welder, slot 2: the artifact card in the graveyard of the first
## target's controller — and the swap, done only when BOTH targets are
## still legal (the engine re-judged this slot; the first is re-judged
## here, the Gauntlets of Chaos shape, leg/gauntlets_of_chaos.gd).
class Weld extends EffectBase:
	var first_spec: TargetSpec
	func _init(p_first_spec: TargetSpec) -> void:
		first_spec = p_first_spec
		target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_ANY_GRAVEYARD,
			"target artifact card in that player's graveyard", _artifact_card) \
			.with_sibling_filter(_in_that_players_graveyard, TargetSpec.WHY["owner"])
	static func _artifact_card(i: CardInstance) -> bool:
		return i.data.is_type(Mtg.CardType.ARTIFACT)
	static func _in_that_players_graveyard(g: MtgGame, _s: CardInstance, candidate: TargetRef, earlier: Array) -> bool:
		var artifact := g.find_instance((earlier[0] as TargetRef).instance_id)
		var card := g.find_instance(candidate.instance_id)
		return artifact != null and card != null and card.owner_id == artifact.controller_id
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var slots := g.current_targets()
		if slots.size() < 2 or t == null:
			return
		var first: TargetRef = slots[0]
		if not first_spec.is_legal(g, first, s):
			return
		var artifact := g.find_instance(first.instance_id)
		var card := g.find_instance(t.instance_id)
		if not g.is_present(artifact) or card == null or card.zone != Mtg.Zone.GRAVEYARD:
			return
		var player := artifact.controller_id
		g.begin_simultaneous()
		g.sacrifice_permanent(artifact)
		g.reanimate(card, player)
		g.end_simultaneous()
	func describe() -> String:
		return "that player simultaneously sacrifices the artifact and returns the artifact card to the battlefield"
