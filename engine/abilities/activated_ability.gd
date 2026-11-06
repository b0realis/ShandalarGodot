class_name ActivatedAbility
extends RefCounted
## An activated ability: "[cost]: [effect]." — e.g. Prodigal Sorcerer's
## "{T}: Prodigal Sorcerer deals 1 damage to any target."
##
## Costs are declarative fields on this object, all of them optional and all
## combinable: mana ([member cost], with an {X} rider via
## [member x_color]), {T} ([member tap_cost]), sacrificing the source
## ([member sacrifice_cost]) or another permanent
## ([member sacrifice_filter]), exiling the source ([member exile_cost]),
## paying life ([member life_cost]), discarding at random
## ([member random_discard_cost]), and removing counters
## ([member counter_cost_kind]). Timing riders — combat only, one step, one
## side's turn, N per turn, who may activate at all — sit alongside them.
## ALL of it is enforced and paid in MtgGame.activate_ability and nowhere
## else, which is what keeps the "costs are paid before anything resolves"
## rule (CR 601.2h) in one auditable place.
##
## Activation uses the stack: MtgGame.activate_ability pays the cost
## immediately (costs are not undoable), then puts a StackItem of kind
## ABILITY on the stack carrying [member effects]; targets are chosen at
## activation and validated again on resolution, exactly like a spell.
##
## Tap-cost abilities of creatures are subject to summoning sickness
## (CR 602.5g) — MtgGame enforces that; the ability itself stays declarative.

## Mana part of the cost (empty ManaCost = free).
var cost: ManaCost
## Opt-in, generic-cost storage artifacts: the player chooses the actual
## mana types spent before payment. Each activation captures its own record.
var capture_mana_spent := false

## Whether the cost includes tapping the source ({T}).
var tap_cost: bool = false
## Only this zone grants activation permission. Putting an activated
## ability in a card definition does not make it usable from every zone.
var activation_zone: int = Mtg.Zone.BATTLEFIELD

func from_graveyard() -> ActivatedAbility:
	activation_zone = Mtg.Zone.GRAVEYARD
	return self

## Pack 10 E2: an ability that functions only while its card is in its
## OWNER'S HAND — cycling (CR 702.29a, 113.6). Only the owner may activate
## it (a card in a hand is not a permanent and has no controller, CR 109.2,
## 108.4); it uses the stack like every other activated ability (CR 602.2),
## and a cycling LAND on the battlefield has no such ability to activate.
func from_hand() -> ActivatedAbility:
	activation_zone = Mtg.Zone.HAND
	return self

## Pack 10 E2: "Discard this card" as part of the cost (cycling, CR
## 702.29a). The source itself leaves its owner's hand for the graveyard as
## the cost is paid (CR 601.2h) — a COST discard, [method
## MtgGame.discard_cards] with `by_effect` false: Library of Leng has no
## say, "whenever a player discards" triggers fire (Megrim, CR 701.8), and
## Psychic Purge's "a spell or ability an opponent controls causes you to
## discard" does not. Payable only while the card is in the payer's hand;
## recorded on the activation as `_discarded_name` / `_discarded_types`.
var discard_self_cost: bool = false

## Fluent: add "Discard this card" to the cost (see [member discard_self_cost]).
func with_discard_self_cost() -> ActivatedAbility:
	discard_self_cost = true
	return self

## Pack 10 E2: this is a CYCLING ability (CR 702.29a) — the marker
## "cycling abilities you activate cost {2} less" reads (Fluctuator, through
## [method CardData.with_ability_cost_reduction]), and the AI and the help
## read. Set by [method CardData.with_cycling].
var is_cycling: bool = false

## Fluent: mark this ability as a cycling ability (see [member is_cycling]).
func as_cycling() -> ActivatedAbility:
	is_cycling = true
	return self

## "Sacrifice this permanent" as part of the cost (Strip Mine). Paid after
## mana/tap — the source is in the graveyard while the ability resolves.
var sacrifice_cost: bool = false

## "Pay N life" as part of the cost (Greed). Payable down to exactly 0
## life (CR 118.4 — and yes, that kills you via state-based actions).
var life_cost: int = 0

## Exiling the top cards is an announcement cost, not a resolving effect.
## Only the size is queried before payment; no chooser/AI sees future cards.
var library_exile_cost := 0
## Declarative object costs — groups built by engine/additional_object_costs.gd
## ("Return a Forest you control to its owner's hand", "Exile the top
## creature card of your graveyard"). Validated, chosen and paid by
## MtgGame.activate_ability with the rest of the cost (CR 602.2b).
var object_costs: Array = []

## Fluent: add one object-cost group (see [member object_costs]).
func with_object_cost(group: Dictionary) -> ActivatedAbility:
	object_costs.append(group)
	return self

## "Return this permanent to its owner's hand" as part of the cost (Cycle
## of Life, Gossamer Chains, Ovinomancer — CR 602.2b). Paid after mana and
## {T}, like [member sacrifice_cost]; the source is in its owner's hand
## while the ability resolves, so its effects must not read battlefield
## state about itself (the activation's `cost_paid` keeps
## `_source_returned` and the source's last timestamp).
var return_cost: bool = false

## Fluent: add "Return this permanent to its owner's hand" to the cost.
func with_return_cost() -> ActivatedAbility:
	return_cost = true
	return self

func with_library_exile_cost(count: int) -> ActivatedAbility:
	library_exile_cost = maxi(0, count)
	return self


## Fluent: add "Sacrifice this permanent" to the cost.
func with_sacrifice_cost() -> ActivatedAbility:
	sacrifice_cost = true
	return self


## "Exile this permanent" as part of the cost (Feldon's Cane). Paid after
## mana/tap; the source is in exile while the ability resolves, so its
## effects must not read battlefield state about itself.
var exile_cost: bool = false

## "Discard N cards at random" as part of the cost (Coral Helm). 0 = none.
## At RANDOM, so it needs no chooser — the discard rolls on game.rng and
## stays deterministic under a seed.
var random_discard_cost: int = 0

## Fluent: add a random-discard cost.
func with_random_discard_cost(n: int) -> ActivatedAbility:
	random_discard_cost = n
	return self


## Fluent: add "Exile this permanent" to the cost.
func with_exile_cost() -> ActivatedAbility:
	exile_cost = true
	return self


## Fluent: add "Pay [amount] life" to the cost.
func with_life_cost(amount: int) -> ActivatedAbility:
	life_cost = amount
	return self


## Pack 10 E2: a life cost whose amount is worked out as the cost is paid
## — `func(game: MtgGame, source: CardInstance, pid: int) -> int` (Lurking
## Evil's "Pay half your life, rounded up:"). Invalid = the fixed
## [member life_cost]. Every reader asks [method MtgGame.ability_life_cost],
## never this field or [member life_cost] alone, so the refusal, the
## payment and the AI's price agree.
var life_cost_fn: Callable = Callable()

## Fluent: make the life cost [param fn]'s answer (see [member life_cost_fn]).
func with_life_cost_fn(fn: Callable) -> ActivatedAbility:
	life_cost_fn = fn
	return self

## Fluent: "Pay half your life, rounded up" (Lurking Evil) — see
## [method half_life_rounded_up].
func with_half_life_cost() -> ActivatedAbility:
	life_cost_fn = half_life_rounded_up
	return self

## "Half your life, rounded up" (CR 107.1a): 7 life pays 4, 1 pays 1, and a
## life total of 0 or less pays 0 — a player can always pay 0 life
## (CR 119.4, 107.1b).
static func half_life_rounded_up(game: MtgGame, _source: CardInstance, pid: int) -> int:
	var life: int = game.players[pid].life
	return 0 if life <= 0 else ceili(life / 2.0)

## Does this ability's cost include paying life at all — a fixed amount or
## a worked-out one? For the readers that only ask whether a life payment
## is involved; the AMOUNT is [method MtgGame.ability_life_cost]'s.
func has_life_cost() -> bool:
	return life_cost > 0 or life_cost_fn.is_valid()


## "Activate only during combat." (Jade Statue.) Enforced by
## MtgGame.activate_ability against Mtg.is_combat_step.
var only_during_combat: bool = false

## Fluent: restrict activation to combat steps.
func combat_only() -> ActivatedAbility:
	only_during_combat = true
	return self


## "Activate only during [step]" (Desert's end-of-combat ping, Hell's
## Caretaker's upkeep). One Mtg.Step value; -1 = no restriction.
## Enforced by MtgGame.activate_ability.
var only_during_step: int = -1

## Fluent: restrict activation to one step of the turn.
func during_step(step: int) -> ActivatedAbility:
	only_during_step = step
	return self


## "Activate only before [step]" (Angus Mackenzie's "only before the
## combat damage step"). -1 = no restriction; open while such a step
## still lies ahead this turn (MtgGame.step_is_ahead — so a turn with an
## extra combat has the window before each of them).
var only_before_step: int = -1

## Fluent: restrict activation to before a given step of the turn.
func before_step(step: int) -> ActivatedAbility:
	only_before_step = step
	return self


## "Activate only during your turn" (Gwendlyn Di Corci, Nebuchadnezzar)
## or "only during an opponent's turn" (Nettling Imp). 0 = no
## restriction, 1 = your turn only, -1 = an opponent's turn only.
var turn_restriction: int = 0

## Fluent: activate only during your own turn.
func your_turn_only() -> ActivatedAbility:
	turn_restriction = 1
	return self

## Fluent: activate only during an opponent's turn.
func opponents_turn_only() -> ActivatedAbility:
	turn_restriction = -1
	return self


## "Only your opponents may activate this ability" (Clergy of the Holy
## Nimbus). MtgGame.activate_ability normally demands the activator
## CONTROL the permanent; this inverts that one check.
var only_opponents_may_activate: bool = false

## Fluent: hand this ability to the opponents (Clergy of the Holy Nimbus).
func opponent_activated() -> ActivatedAbility:
	only_opponents_may_activate = true
	return self


## "Only this permanent's OWNER may activate this ability" (Personal
## Incarnation). Different from the controller requirement every other
## ability has: a stolen Personal Incarnation still answers only to the
## player who owns it, which is the whole flavour of the card.
var only_owner_may_activate: bool = false

## Fluent: restrict activation to the permanent's owner.
func owner_only() -> ActivatedAbility:
	only_owner_may_activate = true
	return self


## "Any player may activate this ability" (Ifh-Biff Efreet, Land's Edge,
## Armageddon Clock). MtgGame drops the control requirement entirely.
var any_player_may_activate: bool = false

## Fluent: let ANY player activate this ability.
func anyone_activated() -> ActivatedAbility:
	any_player_may_activate = true
	return self


## "Activate only [N times] each turn" (Fire Drake once, Vampire Bats
## twice). 0 = unlimited. Tracked per instance in
## CardInstance.ability_uses, reset every cleanup.
var max_per_turn: int = 0

## Fluent: cap activations per turn. The ONE place a cap is set, so it is
## also the one place the cap is SAID: an ability [member text] that does
## not already state it gets the printed sentence appended — "Activate
## only once each turn." / "Activate no more than twice (three times) each
## turn." — so the menu and the log read what the card says (Spitting
## Drake, Kyscu Drake and Wild Aesthir did not; Mirage bug pass, H4-F5).
## A text that already says it, or an empty one, is left alone.
func per_turn(n: int) -> ActivatedAbility:
	max_per_turn = n
	if n > 0 and text != "" \
			and not text.to_lower().contains(per_turn_words(n) + " each turn"):
		var sentence := "Activate only once each turn." if n == 1 \
			else "Activate no more than %s each turn." % per_turn_words(n)
		text = text + (" " if text.ends_with(".") else ". ") + sentence
	return self


## "once", "twice", "three times" … — the count as the oracle words it.
static func per_turn_words(n: int) -> String:
	const WORDS := ["", "once", "twice", "three times", "four times", "five times"]
	return WORDS[n] if n >= 0 and n < WORDS.size() else "%d times" % n


## "X can't be 0" (Aladdin's Lamp) — the smallest X this ability accepts.
## 0 = no floor, which is every other {X} ability in the pool. Enforced by
## MtgGame.activate_ability as a REFUSAL, before any cost is paid, because
## a player who names an illegal X has made a player-level mistake and the
## engine's contract is to say so (CONTRIBUTING.md rule 3).
var min_x: int = 0

## Fluent: set the floor on this ability's X (see [member min_x]).
func with_min_x(n: int) -> ActivatedAbility:
	min_x = n
	return self


## An extra check on the chosen X, which may also read the chosen TARGETS:
## [code]func(game: MtgGame, source: CardInstance, x_value: int,
## targets: Array) -> String[/code], returning "" when the activation is
## legal or a human-readable refusal otherwise. Reflecting Mirror's "X is
## twice the mana value of that spell" is the pool's only user, and it
## needs the target to know what X must be. Checked in
## MtgGame.activate_ability before any cost is paid.
var x_condition: Callable = Callable()

## Fluent: attach an X/target condition (see [member x_condition]).
func with_x_condition(cb: Callable) -> ActivatedAbility:
	x_condition = cb
	return self


## "Pay {C} for each ..." — the ability's X is paid in COLOURED mana of
## this Mtg.ManaColor instead of generic (Goblin Polka Band's "{2}, {T},
## Pay {R} for each target"). 0 = the usual generic X.
var x_color: int = 0

## Fluent: make this ability's X a coloured payment (see [member x_color]).
func with_colored_x(color: int) -> ActivatedAbility:
	x_color = color
	return self


## A SHALLOW copy of this ability — same effects, same riders, its own
## cost. Used by effects that rewrite a permanent's LIVE abilities
## (Power Artifact's {2} discount); copies every script variable, so new
## riders are picked up automatically.
func shallow_copy() -> ActivatedAbility:
	var out := ActivatedAbility.new("", tap_cost, [], text)
	for prop in get_property_list():
		if (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			out.set(prop.name, get(prop.name))
	# The per-grantor cache is this object's own (Pack 10 E2): shared, the
	# copy would hold the dictionary that holds the copy — a reference cycle.
	out._granted_copies = {}
	return out


## Pack 10 E2 — THE GRANTOR LINK (CR 613.7: a granted ability belongs to
## the object it is granted to, but its text may name the object that grants
## it — Archery Training's "where X is the number of arrow counters on
## Archery Training"). The id of the permanent that grants this copy, -1 on
## every printed ability. Stamped onto each activation's cost record as
## `_grantor`, `_grantor_timestamp` and `_grantor_counters` by
## MtgGame.activate_ability; read back with [method grantor_counters].
var grantor_id: int = -1

## Copies already made by [method granted_by], keyed by grantor id. A cache,
## never game state: a copy carries nothing but the grantor's id, so the
## same id in two games may share one. Guarded by [member _grant_mutex] —
## the Deck Lab runs games on a WorkerThreadPool over one shared registry.
var _granted_copies: Dictionary = {}
static var _grant_mutex := Mutex.new()


## THIS ability as granted by [param grantor] — a shallow copy that knows
## its grantor ([member grantor_id]), the SAME copy every recalculation (a
## static that appends it to its host's live list keeps one identity, as a
## shared printed ability does). Two Archery Trainings on one creature hand
## it two copies, each reading its own Aura. Null [param grantor] = self.
func granted_by(grantor: CardInstance) -> ActivatedAbility:
	if grantor == null:
		return self
	_grant_mutex.lock()
	var copy: ActivatedAbility = _granted_copies.get(grantor.id)
	if copy == null:
		copy = shallow_copy()
		copy.grantor_id = grantor.id
		_granted_copies[grantor.id] = copy
	_grant_mutex.unlock()
	return copy


## The [param kind] counters on the GRANTOR of the ability being resolved
## (see [member grantor_id]): its live count while that very permanent is
## still on the battlefield, else the count it had as the ability was
## activated (last known information, CR 608.2h). 0 when the ability being
## resolved was not granted by a permanent.
static func grantor_counters(game: MtgGame, kind: String) -> int:
	var grantor_id_paid := int(game.cost_paid("_grantor", -1))
	if grantor_id_paid < 0:
		return 0
	var grantor := game.find_instance(grantor_id_paid)
	if game.is_present(grantor) \
			and grantor.layer_timestamp == int(game.cost_paid("_grantor_timestamp", -1)):
		return int(grantor.counters.get(kind, 0))
	var snapshot: Dictionary = game.cost_paid("_grantor_counters", {})
	return int(snapshot.get(kind, 0))


## A shallow copy whose mana cost is [param n] generic cheaper.
##
## [param minimum_mana] is Power Artifact's *"This effect can't reduce the
## mana in that cost to less than one mana"* — a FLOOR on the whole cost,
## not on the generic part, so {1}{U} may still lose its generic while {2}
## may only fall to {1}. A cost already at or below the floor is not
## reduced at all, which is what keeps a free ability free. 0 = no floor,
## the shape every other cost reduction in the pool has.
func discounted(n: int, minimum_mana := 0) -> ActivatedAbility:
	var out := shallow_copy()
	var cut := n
	if minimum_mana > 0:
		cut = mini(n, maxi(cost.mana_value() - minimum_mana, 0))
	out.cost = cost.minus_generic(cut)
	return out


## The cost actually paid for an activation with [param x_value]: the
## printed cost, plus X coloured pips when [member x_color] is set.
func cost_for(x_value: int) -> ManaCost:
	if x_color == 0 or x_value <= 0:
		return cost
	return cost.plus_colored(x_color, x_value)


## "Sacrifice a [something]" as part of the cost, where the something is
## ANOTHER permanent chosen by the activating player (Dark Heart of the
## Wood's Forest). Unset = no such cost. The paired description names the
## requirement in refusals and agent prompts.
var sacrifice_filter: Callable = Callable()
var sacrifice_filter_desc: String = ""

## May the "Sacrifice a <desc>" cost eat THE SOURCE ITSELF? "Sacrifice a
## creature" on a creature means any creature you control, this one
## included (Fallen Angel) — but most sources with such a cost are not of
## the type they eat, so the default stays "another permanent" and each
## card that can eat itself says so.
var sacrifice_may_be_source: bool = false

## Fluent: add a "Sacrifice a <desc>" cost (chooser = the player's agent).
func with_sacrifice_of(desc: String, filter: Callable) -> ActivatedAbility:
	sacrifice_filter = filter
	sacrifice_filter_desc = desc
	return self

## Fluent: let that sacrifice cost eat the source (see
## [member sacrifice_may_be_source]).
func may_sacrifice_itself() -> ActivatedAbility:
	sacrifice_may_be_source = true
	return self

## "Sacrifice ANY NUMBER of <desc>" (Sword of the Ages): the sacrifice cost
## above is asked REPEATEDLY, one body at a time, each ask optional, until
## the payer declines or nothing is left — zero is a legal answer, so the
## activation is never refused for want of a body. What went is recorded
## on the stack item under `_sacrificed_names`, `_sacrificed_total_power`
## and `_sacrificed_instances` (see [member StackItem.cost_paid]).
var sacrifice_any_number: bool = false
## Fixed multi-permanent costs (Goblin Warrens). Still paid before resolving.
var sacrifice_count: int = 1

## Fluent: make the sacrifice cost "any number of" (see
## [member sacrifice_any_number]).
func any_number() -> ActivatedAbility:
	sacrifice_any_number = true
	return self

## "Discard a card" as part of the COST, CHOSEN by the paying player
## (Land's Edge). 0 = no such cost; distinct from
## [member random_discard_cost], which needs no chooser. What was discarded
## is recorded on the activation's own [member StackItem.cost_paid] under
## `_discarded_types` and `_discarded_name`, read back through
## [method MtgGame.cost_paid] — Land's Edge's "if the discarded card was a
## land card" is exactly that question. (It lived on the source's `memory`
## until 2026-09-02, one slot per permanent, so two stacked activations
## read each other's record.)
var discard_cost: int = 0
var discard_filter: Callable = Callable()
var discard_filter_desc := "card"

## Fluent: add a "Discard N cards" cost (chooser = the paying player).
func with_discard_cost(n: int) -> ActivatedAbility:
	discard_cost = n
	return self


## "Discard the last card you drew this turn" as part of the cost (Jandor's
## Ring). Nobody chooses: the card is the last entry of
## [member MtgPlayer.drawn_this_turn], and the cost is payable only while
## that card is still in the paying player's hand (CR 601.2g — a cost you
## can't pay can't be paid; a card that has since been played or thrown
## away is not "in your hand" to discard). What went is recorded under
## `_discarded_name` like [member discard_cost]'s pick.
var discard_last_drawn_cost: bool = false

## Fluent: add a "Discard the last card you drew this turn" cost.
func with_discard_last_drawn_cost() -> ActivatedAbility:
	discard_last_drawn_cost = true
	return self


## "Exile a <desc> you control" as part of the cost (City of Shadows'
## creature). Unset = no such cost. Paid in MtgGame.activate_ability with
## the rest of the cost (CR 601.2h), chosen by the activating player, and
## the exiled permanent's mana value is left on the source's memory under
## `_exiled_mana_value` exactly as the graveyard version does.
var exile_filter: Callable = Callable()
var exile_filter_desc: String = ""

## Fluent: add an "Exile a <desc> you control" cost.
func with_exile_of(desc: String, filter: Callable) -> ActivatedAbility:
	exile_filter = filter
	exile_filter_desc = desc
	return self


## "Exile a <desc> from your GRAVEYARD" as part of the cost (Necropolis's
## corpse). Unset = no such cost. Paid in MtgGame.activate_ability with the
## rest of the cost (CR 601.2h), so two activations can never eat the same
## card, and the exiled card's mana value is left on the source's memory
## under `_exiled_mana_value` for the ability's own effects to read.
var graveyard_exile_filter: Callable = Callable()
var graveyard_exile_desc: String = ""
var graveyard_exile_count := 1
var graveyard_exile_any_player := false

## Additional non-{T} taps can include summoning-sick creatures.
var tap_permanent_filter: Callable = Callable()
var tap_permanent_count := 0

## Optional activator restriction: Callable(game, source, pid) -> String.
## Merseine belongs to the Aura but only its host's controller may pay.
var activator_condition: Callable = Callable()

## Bookkeeping at cost payment, before the ability can be countered.
## Callable(game, source, paid_costs). May not ask additional questions.
var on_cost_paid: Callable = Callable()

## Fluent: add an "Exile a <desc> from your graveyard" cost.
func with_exile_from_graveyard(desc: String, filter: Callable) -> ActivatedAbility:
	graveyard_exile_filter = filter
	graveyard_exile_desc = desc
	return self


## "Remove N <kind> counters from this permanent" as part of the COST
## (Triskelion's +1/+1, Osai Vultures' carrion pair, Scavenging Ghoul's
## corpse). Empty kind = no such cost. Checked and PAID in
## MtgGame.activate_ability with the rest of the cost (CR 601.2h), so two
## activations can never spend the same counter — which is exactly what
## happens if the removal lives in the resolving effect instead.
var counter_cost_kind: String = ""
var counter_cost_count: int = 0

## Fluent: add a "Remove [param count] [param kind] counters" cost.
func with_counter_cost(kind: String, count := 1) -> ActivatedAbility:
	counter_cost_kind = kind
	counter_cost_count = count
	return self


## Optional extra ACTIVATION condition:
## [code]func(game: MtgGame, source: CardInstance) -> String[/code],
## returning "" when the ability may be activated or a human-readable
## refusal otherwise (Eater of the Dead's "only while it is tapped").
## Checked by MtgGame.activate_ability before any cost is paid.
var activation_condition: Callable = Callable()

## Fluent: attach an activation condition (see [member activation_condition]).
func only_if(cb: Callable) -> ActivatedAbility:
	activation_condition = cb
	return self


## The effects that resolve, in order. Effects with a target_spec demand a
## target at activation time.
var effects: Array[EffectBase] = []

## Card-English text of the whole ability, for UI menus and logs.
var text: String = ""


func _init(p_cost: String, p_tap: bool, p_effects: Array, p_text: String = "") -> void:
	cost = ManaCost.parse(p_cost)
	tap_cost = p_tap
	for e in p_effects:
		effects.append(e)
	text = p_text


## The target specs the ACTIVATOR supplies refs for, in effect order (used
## by the caller to know how many TargetRefs to supply). A spec an
## opponent chooses ([member TargetSpec.chosen_by_opponent] — Arena's
## second creature) or the game rolls ([member TargetSpec.chosen_at_random]
## — the Polka Band's victims) is left out: the engine fills it as the
## ability is activated, and the activator never names it
## ([method TargetSpec.is_supplied_by_caster]).
func target_specs() -> Array[TargetSpec]:
	var specs: Array[TargetSpec] = []
	for e in effects:
		if e.target_spec != null and e.target_spec.is_supplied_by_caster():
			specs.append(e.target_spec)
	return specs


func _to_string() -> String:
	return text if text != "" else "activated ability"
