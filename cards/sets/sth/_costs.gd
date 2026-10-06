extends RefCounted
## Stronghold (_costs, Pack 9). Additional and alternative costs, upkeep costs and cost modifiers.
##
## "As an additional cost to cast this spell, sacrifice a creature"
## (Fling, Mask of the Mimic, Scapegoat) is CardData.with_additional_sacrifice:
## exactly one body, chosen and sacrificed as the spell is cast (CR
## 601.2h), so nobody can respond to the sacrifice (the rulings). Dream
## Halls GRANTS every spell an alternative cost (engine package E2);
## Heartstone is E7's ability-cost reduction with a one-mana floor;
## Hidden Retreat pays E7's "put a card from your hand on top of your
## library". Tests: tests/cards/test_pack_9_B2_costs_sth_exo.gd.
const OC := preload("res://engine/additional_object_costs.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Hidden Retreat":
			c.activated(ActivatedAbility.new("", false, [RetreatShield.new()],
				"Put a card from your hand on top of your library: Prevent all damage that would be dealt by target instant or sorcery spell this turn.") \
				.with_object_cost(OC.putting_on_top()))
		"Scapegoat":
			c.with_additional_sacrifice("creature", _creature)
			var home := ReturnToHandEffect.new(TargetSpec.creature("target creature you control") \
				.with_source_filter(_yours).because(TargetSpec.WHY["controller"]))
			home.target_min = 0
			home.target_max = -1
			home.ai_helpful = true
			c.spell(home)
		# ------------------------------------------------------------- blue
		"Dream Halls": c.with_granted_alternative_cost(_halls_rows)
		"Mask of the Mimic":
			c.with_additional_sacrifice("creature", _creature)
			c.spell(MimicSearch.new())
		# -------------------------------------------------------------- red
		"Fling":
			c.with_additional_sacrifice("creature", _creature)
			c.spell(FlingDamage.new())
		# --------------------------------------------------------- artifact
		"Heartstone": c.with_ability_cost_reduction(1, _creature_ability, 1)
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()

## "you control" is the caster's (CR 109.5): the stack item's controller.
static func _yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s == null or i.controller_id == g.controller_acting_for(s)


# ----------------------------------------------------------------- Dream Halls

## "Rather than pay the mana cost for a spell, its controller may discard a
## card that shares a color with that spell." Every player's spells; a
## colourless spell shares a colour with nothing; the spell is never its
## own payment; X is 0 (CR 107.3b); buyback and other additional costs are
## still paid on top (the Dream Halls ruling) — MtgGame.payment_rows.
static func _halls_rows(_g: MtgGame, _pid: int, spell: CardInstance, _source: CardInstance) -> Array:
	if spell.cur_colors == 0:
		return []
	var group := OC.discarding("card that shares a color with it")
	group["source_filter"] = _shares_color
	return [{"label": "Discard a card that shares a color with it (Dream Halls)", "object_costs": [group]}]

static func _shares_color(_g: MtgGame, card: CardInstance, spell: CardInstance) -> bool:
	return spell != null and (card.cur_colors & spell.cur_colors) != 0


# ------------------------------------------------------------------ Heartstone

## "Activated abilities of creatures cost {1} less to activate. This effect
## can't reduce the mana in that cost to less than one mana." Every
## player's creatures; never a coloured pip, never a {1} added to an
## ability with no generic mana (the rulings — MtgGame.ability_payment).
## "Creatures" are creature PERMANENTS (CR 109.2): a creature card in a
## graveyard (Carrionette, Necrosavant) pays in full (bug pass 2026-10-06).
static func _creature_ability(g: MtgGame, _pid: int, source: CardInstance,
		_ability: ActivatedAbility, _modifier: CardInstance) -> bool:
	return g.is_present(source) and source.is_creature()


# -------------------------------------------------------------- Hidden Retreat

## "Prevent all damage that would be dealt by target instant or sorcery
## spell this turn." Damage from THAT spell object (the card on the stack
## that deals it) to any creature or player, for the rest of the turn —
## a copy is another object and is not covered. Legal in the 1997
## damage-prevention window.
class RetreatShield extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell("target instant or sorcery spell", RetreatShield._instant_or_sorcery)
		is_damage_prevention = true
		ai_helpful = true
		with_ai_role(&"spell_damage_shield")
	static func _instant_or_sorcery(i: CardInstance) -> bool:
		return i.data.is_type(Mtg.CardType.INSTANT) or i.data.is_type(Mtg.CardType.SORCERY)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var spell := g.find_instance(t.instance_id) if t != null else null
		if spell == null or spell.zone != Mtg.Zone.STACK: return
		g.add_damage_effect({"kind": &"prevent", "controller": pid, "card": s.data.card_name,
			"source": spell, "desc": "%s (%s)" % [s.data.card_name, spell.data.card_name]})
		g.log_line("%s: all damage %s would deal this turn is prevented" % [
			s.data.card_name, spell.data.card_name])
	func describe() -> String:
		return "prevent all damage that would be dealt by target instant or sorcery spell this turn"


# ----------------------------------------------------------- Mask of the Mimic

## "Search your library for a card with the same name as target nontoken
## creature, put that card onto the battlefield, then shuffle." The name
## is the target's as it resolves (a copy has the name it copies — the
## ruling), any card type; finding nothing is legal.
class MimicSearch extends SearchLibraryEffect:
	func _init() -> void:
		super("a card with the same name as target nontoken creature")
		to_battlefield()
		target_spec = TargetSpec.creature("target nontoken creature", MimicSearch._nontoken)
	static func _nontoken(i: CardInstance) -> bool: return not i.is_token
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var model := g.find_instance(t.instance_id) if t != null else null
		if model == null or model.zone != Mtg.Zone.BATTLEFIELD: return
		var wanted := model.data.card_name
		g.search_library(pid, func(i: CardInstance) -> bool: return i.data.card_name == wanted,
			"Mask of the Mimic: search for a card named %s" % wanted, true)
	func describe() -> String:
		return "search your library for a card with the same name as target nontoken creature, put it onto the battlefield, then shuffle"


# ----------------------------------------------------------------------- Fling

## "Fling deals damage equal to the sacrificed creature's power to any
## target." — its power as it last existed on the battlefield (the
## ruling), recorded by the cast as the cost was paid.
class FlingDamage extends DamageEffect:
	func _init() -> void:
		super(0)
		any_target()
		with_ai_role(&"sacrificed_power_damage")
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		if t == null: return
		var power := int(g.cost_paid("_sacrificed_power", s.memory.get("sacrificed_power", 0)))
		if power > 0: g.deal_damage(s, t, power)
	func describe() -> String:
		return "deals damage equal to the sacrificed creature's power to any target"
