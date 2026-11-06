extends RefCounted
## Urza's Destiny (_misc, Pack 10). Everything else: global effects and
## one-off rules — the cards each built on one small engine package.
##
## - Archery Training (Pack 10 E2's grantor link): the Aura grants its
##   creature one copy of the arrow shot per Training
##   (ActivatedAbility.granted_by — two Trainings, two abilities), and the
##   shot reads the arrow counters on the Training that granted it: live
##   while that very Aura is on the battlefield, else the count it had as
##   the ability was activated (ActivatedAbility.grantor_counters, CR 613.7,
##   608.2h). "You may put an arrow counter" is asked at each of its
##   controller's upkeeps, on the Aura that triggered.
## - Compost (Pack 10 E4, Mtg.EventType.CARD_PUT_INTO_GRAVEYARD): a black
##   CARD — as it is in the graveyard, printed colours again (CR 400.7) —
##   put into an opponent's graveyard; never a token, never a card a
##   graveyard replacement exiled instead. "You may draw" is its
##   controller's question.
## - Replenish (Pack 10 E10, MtgGame.put_onto_battlefield_together): every
##   enchantment card in your graveyard arrives TOGETHER; an Aura chooses a
##   host among the permanents already on the battlefield (CR 303.4f), and
##   one with nothing to enchant stays in the graveyard (CR 303.4g).
## - Metalworker (Pack 10 E8, ManaAbility.with_reveal_from_hand): "{T}:
##   Reveal any number of artifact cards in your hand. Add {C}{C} for each
##   card revealed this way." — how many (and which) is asked with the
##   activation; the revealed names go to both players (CR 605.1a, 701.16a).
## - Storage Matrix (Pack 10 E9, MtgGame.restrict_untap_to_chosen_kind):
##   while it is untapped, each player chooses artifact, creature or land
##   in their untap step and untaps only that kind (CR 502.3).
## tests/cards/test_pack_10_B13_*.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const UC := preload("res://cards/sets/usg/_creatures.gd")

const GRAVE := Mtg.EventType.CARD_PUT_INTO_GRAVEYARD
const UPKEEP := Mtg.EventType.UPKEEP_START
const SHOT_LINE := "{T}: This creature deals X damage to target attacking or blocking creature, where X is the number of arrow counters on Archery Training."


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Archery Training":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(UPKEEP, _arrow_upkeep,
				"At the beginning of your upkeep, you may put an arrow counter on this Aura.",
				F._your_upkeep))
			# ONE shot per definition: each Training hands its creature its
			# own copy of it (granted_by), the same copy every recalculation.
			var shot := ActivatedAbility.new("", true, [ArrowShot.new()], SHOT_LINE)
			c.static_ability(StaticAbility.new(_grant_shot.bind(shot),
				"Enchanted creature has \"" + SHOT_LINE + "\"").changing_abilities())
		"Compost":
			c.triggered(TriggeredAbility.new(GRAVE, _compost_draw,
				"Whenever a black card is put into an opponent's graveyard from anywhere, you may draw a card.",
				_black_into_an_opponents))
		"Metalworker":
			c.mana(ManaAbility.new(Mtg.ManaColor.C, 0).with_reveal_from_hand(_artifact_card, "artifact", 2))
		"Storage Matrix":
			c.static_ability(StaticAbility.new(_matrix,
				"As long as this artifact is untapped, each player chooses artifact, creature, or land during their untap step. That player can untap only permanents of the chosen type this step."))
		"Replenish":
			c.spell(F.Action.new(_replenish,
				"return all enchantment cards from your graveyard to the battlefield", null, true))
		_: return false
	return true


# --------------------------------------------------------- Archery Training --

static func _arrow_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s):
		return
	var pid := g.controller_acting_for(s)
	if g.agents[pid].choose_yes_no(g, pid, "Put an arrow counter on %s?" % s.data.card_name, true):
		g.add_counters(s, "arrow")


static func _grant_shot(g: MtgGame, aura: CardInstance, shot: ActivatedAbility) -> void:
	var host := g.find_instance(aura.attached_to)
	if g.is_present(host):
		host.cur_activated_abilities.append(shot.granted_by(aura))


## "This creature deals X damage to target attacking or blocking creature,
## where X is the number of arrow counters on Archery Training."
class ArrowShot extends EffectBase:
	func _init() -> void:
		target_spec = UC.in_combat_creature()

	func resolve(game: MtgGame, source: CardInstance, _controller: int, target: TargetRef,
			_x_value: int = 0) -> void:
		var x := ActivatedAbility.grantor_counters(game, "arrow")
		if x > 0:
			game.deal_damage(source, target, x)

	func describe() -> String:
		return "deals X damage to target attacking or blocking creature, where X is the number of arrow counters on Archery Training"


# ------------------------------------------------------------------ Compost --

static func _black_into_an_opponents(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var card: CardInstance = e.data.get("instance")
	return card != null and int(e.data.get("owner", -1)) != s.controller_id \
		and card.has_color(Mtg.ManaColor.B)


static func _compost_draw(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := g.controller_acting_for(s)
	if g.agents[pid].choose_yes_no(g, pid, "Draw a card (%s)?" % s.data.card_name, true):
		g.draw_cards(pid, 1)


# ---------------------------------------------------------------- Replenish --

static func _replenish(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var entries: Array = []
	for card in g.players[pid].graveyard.duplicate():
		if (card as CardInstance).is_type(Mtg.CardType.ENCHANTMENT):
			entries.append({"instance": card, "controller": pid})
	g.put_onto_battlefield_together(entries)


# -------------------------------------------------------------- Metalworker --

static func _artifact_card(card: CardInstance) -> bool:
	return card.data.is_type(Mtg.CardType.ARTIFACT)


# ----------------------------------------------------------- Storage Matrix --

static func _matrix(g: MtgGame, s: CardInstance) -> void:
	if not s.tapped:
		g.restrict_untap_to_chosen_kind(s)
