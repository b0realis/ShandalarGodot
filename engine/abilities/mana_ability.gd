class_name ManaAbility
extends RefCounted
## A tap-for-mana ability ("{T}: Add {G}", Sol Ring's "{T}: Add {C}{C}").
##
## Mana abilities are deliberately NOT ActivatedAbility subclasses: per
## CR 605.3 they do not use the stack, cannot be responded to, and are
## usable in the middle of paying costs. MtgGame.tap_for_mana activates
## them directly.
##
## [member produces] lists (color, amount) pairs added to the controller's
## pool on activation. Multi-option lands (duals: "Add {W} or {U}") are
## modeled as several ManaAbility entries on the card; the caller picks one
## by index.

## Array of [color: Mtg.ManaColor, amount: int] pairs, all added on
## activation. The FIRST pair is the one [member dynamic_amount] and
## [member dynamic_color] rewrite; later pairs are always literal.
var produces: Array = []

## A replacement of the type produced, not a change to the ability's cost
## or amount. Separate variants let a player choose which of several
## applicable "instead of any other type" replacements applies last.
var forced_output_color: int = 0
var controller_replacement := false
var unreplaced_ability: ManaAbility

## A copy of this ability whose mana comes out as [param color]. Two
## wordings, two modes:
## - "produces {U} instead of any other TYPE" (Deep Water, the land-wide
##   replacements — the default): EVERY mana it makes, colourless included;
##   [member forced_output_color] carries it, and MtgGame.tap_for_mana
##   recolours the activation's whole total, whatever a dynamic amount made.
## - [param colored_only] — "produce mana of the chosen color instead of any
##   other COLOR" (Hall of Gemstone): colourless is not a colour (CR 105.1,
##   105.2c), so only the coloured part changes and a Karoo's {C}{U} makes
##   {C}{R}. Here the result is written into [member produces] itself and
##   [member forced_output_color] stays 0, so the tap, the planner and the
##   menu all read the same literal {C}{R} (a dynamic amount still scales
##   the first entry). A first entry whose colour is decided at activation
##   ([member dynamic_color], [member color_options]) makes a colour, so it
##   takes the forced one.
## Every rider (costs, amount, restriction, side effect) travels with the
## copy, and a later full replacement over it replaces everything again.
##
## [param fixed_amount] (Pack 10 E8) — "instead of any other type AND
## AMOUNT" (Contamination, CR 106.6 / 614.1a): above 0, the copy makes
## exactly that many of [param color] and nothing else — a Karoo's {C}{U},
## a Gaea's Cradle's {G} per creature, a battery's spent counters all
## become one {B}. Every AMOUNT rider is dropped with the old output
## ([member dynamic_amount], [member any_number_counter_kind],
## [member scales_with_sacrifice_mv], [member reveal_filter]); the costs,
## restriction and side effect still travel. 0 keeps the amount.
func forcing_color(color: int, controller_only := false, colored_only := false,
		fixed_amount := 0) -> ManaAbility:
	var copy := ManaAbility.new(0, 0)
	for prop in get_property_list():
		if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: copy.set(prop.name, get(prop.name))
	copy.forced_output_color = 0 if colored_only else color
	copy.controller_replacement = controller_only
	copy.unreplaced_ability = self
	var chosen_at_activation := dynamic_color.is_valid() or color_options.is_valid()
	copy.dynamic_color = Callable()
	copy.color_options = Callable()
	copy.produces = []
	if fixed_amount > 0:
		copy.produces = [[color, fixed_amount]]
		copy.dynamic_amount = Callable()
		copy.amount_reads_activator = false
		copy.any_number_counter_kind = ""
		copy.bonus_per_counter = 0
		copy.scales_with_sacrifice_mv = false
		copy.reveal_filter = Callable()
		copy.reveal_per_card = 0
		return copy
	for i in produces.size():
		var pair: Array = produces[i]
		var keeps := colored_only and int(pair[0]) == Mtg.ManaColor.C \
			and not (i == 0 and chosen_at_activation)
		copy.produces.append([int(pair[0]) if keeps else color, pair[1]])
	return copy


## A STATIC'S WAY TO REPLACE A LAND'S MANA (Pack 10 E8): "if [param land]
## is tapped for mana, it produces [param color] instead of any other type"
## — and, with [param fixed_amount] above 0, "... and amount"
## (Contamination: {B}, 1). Called from a static on every recalculation;
## writes the land's derived [member CardInstance.cur_land_mana_replacements]
## and [member CardInstance.cur_land_mana_fixed], which the continuous
## pipeline turns into [method forcing_color] copies of every {T} mana
## ability (one variant per final colour, CR 616.1).
static func replace_land_mana(land: CardInstance, color: int, fixed_amount := 0) -> void:
	if not land.cur_land_mana_replacements.has(color):
		land.cur_land_mana_replacements.append(color)
	if fixed_amount > 0:
		var had := int(land.cur_land_mana_fixed.get(color, 0))
		land.cur_land_mana_fixed[color] = fixed_amount if had <= 0 else mini(had, fixed_amount)


## The amount the [param color] variant of [param land]'s replaced mana is
## fixed at, or 0 for "whatever the ability makes". CR 616.1: the land's
## controller orders the replacements, and whichever applies LAST names the
## colour — but an amount, once fixed, stands in every order, since a
## type-only replacement keeps the amount it is handed. So a variant whose
## colour fixes no amount (Deep Water's {U} under Contamination) still makes
## the fixed one; with two fixed amounts the smaller is used (no card in the
## pool has a second).
static func land_fixed_amount(land: CardInstance, color: int) -> int:
	if land.cur_land_mana_fixed.is_empty():
		return 0
	if land.cur_land_mana_fixed.has(color):
		return int(land.cur_land_mana_fixed[color])
	var least := 0
	for amount in land.cur_land_mana_fixed.values():
		if least <= 0 or int(amount) < least:
			least = int(amount)
	return least

## When true the cost also includes sacrificing the source (Black Lotus's
## "{T}, Sacrifice Black Lotus: Add three mana of any one color" — modeled
## as five sacrifice ManaAbilities, one per color, chosen by ability index).
## MtgGame.tap_for_mana performs the sacrifice after producing the mana.
var sacrifice_source: bool = false
var activation_zone := Mtg.Zone.BATTLEFIELD
var exile_source := false
## Object-cost groups (engine/additional_object_costs.gd) — Cadaverous
## Bloom's "Exile a card from your hand", Lion's Eye Diamond's "Discard
## your hand". A source with any is never auto-planned (ManaPlanner).
var object_costs: Array = []

## Fluent: add one object-cost group (see [member object_costs]).
func with_object_cost(group: Dictionary) -> ManaAbility:
	object_costs.append(group)
	return self

## "Activate only as an instant" (Lion's Eye Diamond, CR 605.1a and its
## ruling): only while the activating player HOLDS PRIORITY outside any
## resolution — never in the middle of casting a spell or paying a cost —
## and never auto-tapped by a planner. MtgGame.tap_for_mana refuses it
## otherwise.
var instant_only := false

## Fluent: see [member instant_only].
func as_instant() -> ManaAbility:
	instant_only = true
	return self

## "Activate only N times each turn" (Wall of Roots: once). 0 = unlimited.
## Counted per object in CardInstance.ability_uses under the key
## "mana:<index>", reset every cleanup and when the permanent leaves
## (CR 400.7). ManaPlanner drops an exhausted source.
var max_per_turn := 0

## Fluent: see [member max_per_turn].
func per_turn(n: int) -> ManaAbility:
	max_per_turn = n
	return self

## "Put N <kind> counters on this permanent" as part of the cost (Wall of
## Roots' -0/-1). Paid by MtgGame.tap_for_mana with the rest of the cost;
## a planner uses the source only while the counter does not kill it.
var put_counter_kind := ""
var put_counter_count := 0

## Fluent: see [member put_counter_kind].
func with_put_counter_cost(kind: String, count := 1) -> ManaAbility:
	put_counter_kind = kind
	put_counter_count = count
	return self
## Borrow a mana type from the first permanent named by object_costs.
var borrow_paid_land_type := false

func by_exiling_from_hand() -> ManaAbility:
	activation_zone = Mtg.Zone.HAND
	taps_source = false
	exile_source = true
	return self

## Optional MANA part of the cost ("{2}, {T}: Add one mana of any color"
## — Celestial Prism; Coal Golem's {3}). Paid from the FLOATING pool only
## (mana abilities resolve mid-payment; no auto-tapping here). Null =
## free.
var cost: ManaCost = null

## Opt in to cost-first automatic mana planning. Only fixed single-colour
## outputs with no hidden choices or other unmodelled costs qualify. The
## planner simulates ManaPool payments, never this ability's callbacks.
var planner_conversion: bool = false
## A tap-and-remove-counter source with a fixed public output. One tap
## spends one row, so it cannot reuse the counter (Amulet/Cauldron).
var planner_counter_cost := false

func with_plannable_conversion() -> ManaAbility:
	planner_conversion = true
	return self

## Fluent: add a mana cost to this mana ability.
func with_mana_cost(cost_text: String) -> ManaAbility:
	cost = ManaCost.parse(cost_text)
	return self


## A SHALLOW copy whose mana cost is [param n] generic cheaper, with
## [param minimum_mana] as a floor on the whole cost. A mana ability IS an
## activated ability (CR 605.1a), so anything that discounts activated
## abilities discounts these too — Power Artifact on a Celestial Prism.
## A free ability (`cost == null`) has nothing to reduce.
func discounted(n: int, minimum_mana := 0) -> ManaAbility:
	if cost == null:
		return self
	var out := ManaAbility.new(0, 0)
	for prop in get_property_list():
		if (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			out.set(prop.name, get(prop.name))
	var cut := n
	if minimum_mana > 0:
		cut = mini(n, maxi(cost.mana_value() - minimum_mana, 0))
	out.cost = cost.minus_generic(cut)
	return out


## Whether activating TAPS the source. Almost every mana ability in the
## pool does ("{T}: Add {G}"), but Ashnod's Altar's "Sacrifice a creature:
## Add {C}{C}" has no {T} — it can be activated as often as there are
## bodies to feed it, and works while the Altar is already tapped. Also
## note CR 302.6: summoning sickness gates {T} costs only, so a
## non-tapping mana ability works the turn its source arrives.
var taps_source: bool = true

## Fluent: drop the {T} from the cost (Ashnod's Altar).
func without_tap() -> ManaAbility:
	taps_source = false
	return self


## "Sacrifice a <something>" as part of the cost, where the something is
## ANOTHER permanent chosen by the activating player's DecisionAgent
## (Ashnod's Altar's creature, Priest of Yawgmoth's artifact). Unset = no
## such cost; the paired description names it in refusals and prompts.
var sacrifice_filter: Callable = Callable()
var sacrifice_filter_desc: String = ""
var sacrifice_allows_self := false

func may_sacrifice_itself() -> ManaAbility:
	sacrifice_allows_self = true
	return self

## Fluent: add a "Sacrifice a <desc>" cost to this mana ability.
func with_sacrifice_of(desc: String, filter: Callable) -> ManaAbility:
	sacrifice_filter = filter
	sacrifice_filter_desc = desc
	return self


## Mana produced PER MANA VALUE of the sacrificed permanent instead of a
## fixed amount (Priest of Yawgmoth: "Add an amount of {B} equal to the
## sacrificed artifact's mana value"). 0 = fixed [member produces].
var scales_with_sacrifice_mv: bool = false

## Fluent: scale the produced mana by the sacrificed permanent's mana
## value (the colour comes from [member produces]'s first entry).
func scaling_with_sacrifice() -> ManaAbility:
	scales_with_sacrifice_mv = true
	return self


func _init(color: int, amount: int = 1) -> void:
	produces = [[color, amount]]


## Fluent: mark the cost as including "Sacrifice this permanent".
func with_sacrifice() -> ManaAbility:
	sacrifice_source = true
	return self


## Fluent: produce additional mana on the same activation
## (Sol Ring: ManaAbility.new(Mtg.ManaColor.C, 2) — or chain .and_also for mixes).
func and_also(color: int, amount: int = 1) -> ManaAbility:
	produces.append([color, amount])
	return self


## A copy of this ability producing [param now] wherever it produced
## [param was] — the "mana_color" text change (Quarum Trench Gnomes'
## Plains that taps for {C} instead of {W}). EVERY rider travels with the
## copy: the tap, mana, sacrifice, life and counter costs, the side
## effect, the dynamic amount and colour, the restriction key. The retune
## used to rebuild only [member produces] and so silently dropped all of
## them (2026-09-02). A [member dynamic_color] ability is copied but not
## retuned — it names its colour at activation, over [member produces].
func retuned(was: int, now: int) -> ManaAbility:
	var copy := ManaAbility.new(now)
	for prop in get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			copy.set(prop["name"], get(prop["name"]))
	var swapped: Array = []
	for pair in produces:
		swapped.append([now if int(pair[0]) == was else int(pair[0]), int(pair[1])])
	copy.produces = swapped
	return copy


## "Pay N life" as part of the cost (Standing Stones). Payable down to
## exactly 0 life (CR 118.4).
var life_cost: int = 0

## Fluent: add a life cost to this mana ability.
func with_life_cost(amount: int) -> ManaAbility:
	life_cost = amount
	return self


## WHAT THE TAP COSTS IN LIFE — not a cost the player pays (that is
## [member life_cost], which the planner refuses to model) but damage the
## source deals its controller for being tapped: City of Brass's trigger,
## Elves of Deep Shadow's rider. The engine never reads it; it is the
## planner's knowledge that this mana is not free ([method
## ManaPlanner.cheapest_source_first] taps a Plains before a City, and
## [method AiPlayer._pain_excluded] keeps the AI from paying a life for
## mana that was about to be wasted, or the last life it has).
var pain: int = 0

## Fluent: this source deals [param amount] damage to its controller when
## tapped (see [member pain]).
func hurting(amount: int) -> ManaAbility:
	pain = amount
	return self


## Optional side effect run right after the mana is produced:
## [code]func(game: MtgGame, source: CardInstance, controller: int) -> void[/code].
## For mana abilities whose text does more than add mana (Elves of Deep
## Shadow's "This creature deals 1 damage to you"). It must not use the
## stack — mana abilities never do (CR 605.3b).
var side_effect: Callable = Callable()

## Fluent: attach a side effect (see [member side_effect]).
func with_side_effect(cb: Callable) -> ManaAbility:
	side_effect = cb
	return self


## Optional DYNAMIC amount for the first produced colour:
## [code]func(game: MtgGame, source: CardInstance) -> int[/code]. Used by
## the Urza lands, whose output depends on which siblings you control.
## When set, it replaces produces[0][1]; later entries are unaffected.
var dynamic_amount: Callable = Callable()
var amount_reads_activator := false

## Fluent: compute the amount at activation time (see [member dynamic_amount]).
func with_dynamic_amount(cb: Callable, reads_activator := false) -> ManaAbility:
	dynamic_amount = cb
	amount_reads_activator = reads_activator
	return self

## "You" on an activated ability is its activating player (CR 109.5),
## which can differ from the land's controller under Piracy.
func amount_for(game: MtgGame, source: CardInstance, actor := -1) -> int:
	if not dynamic_amount.is_valid(): return int(produces[0][1])
	if amount_reads_activator: return int(dynamic_amount.call(game, source, source.controller_id if actor < 0 else actor))
	return int(dynamic_amount.call(game, source))


## Optional DYNAMIC COLOUR for the first produced entry:
## [code]func(game: MtgGame, source: CardInstance) -> int[/code] returning
## an Mtg.ManaColor flag. Gem Bazaar taps for "the color last chosen",
## which it keeps in its own CardInstance.memory. When set, it replaces
## produces[0][0].
var dynamic_color: Callable = Callable()

## Fluent: compute the colour at activation time (see [member dynamic_color]).
func with_dynamic_color(cb: Callable) -> ManaAbility:
	dynamic_color = cb
	return self


## Optional COLOUR CHOICE for the first produced entry:
## [code]func(game: MtgGame, source: CardInstance) -> Array[/code] returning
## the Mtg.ManaColor flags on offer RIGHT NOW — Fellwar Stone's census of
## what the opponent's lands could make. The ACTIVATING PLAYER picks one of
## them.
##
## Why this is the engine's job and not the card's: a mana ability never uses
## the stack (CR 605.3a), so there is nothing for the choice pre-flight to
## probe, and the only moment the duel can be HELD OPEN for the answer is
## inside [method MtgGame.tap_for_mana] — before the cost is paid, while
## nothing has been mutated (docs/duel-todo.md §1.3). A card that asked from
## inside [member dynamic_color] would be asking after the source was already
## tapped, and would be asked TWICE besides (once for the mana-trigger
## colour, once by [method produce_into_for]).
##
## An empty array means the ability produces nothing at all — pair it with a
## [member dynamic_amount] that returns 0.
var color_options: Callable = Callable()

## Fluent: let the activating player choose the colour (see
## [member color_options]).
func with_color_choice(cb: Callable) -> ManaAbility:
	color_options = cb
	return self


## "Remove N <kind> counters from this permanent" as part of the cost
## (Rasputin Dreamweaver's dream counters). Empty kind = no such cost;
## checked and paid by MtgGame.tap_for_mana with the rest of the cost.
var counter_cost_kind: String = ""
var counter_cost_count: int = 0

## Fluent: add a "Remove [param count] [param kind] counters" cost.
func with_counter_cost(kind: String, count := 1) -> ManaAbility:
	counter_cost_kind = kind
	counter_cost_count = count
	return self


## "Remove ANY NUMBER of <kind> counters from this permanent: Add {W}, then
## add an additional {W} for each counter removed this way" (the five mana
## batteries). How many is the activating player's choice, made as the
## ability is activated (CR 601.2b — a cost with a variable is announced
## with the rest of the activation), and MtgGame.tap_for_mana asks it
## through the same hold that asks a human which body a sacrifice cost
## eats. Each counter removed adds [member bonus_per_counter] more of the
## FIRST produced colour. Zero is a legal answer: the battery then simply
## taps for its base mana and keeps its charge — which is why this is a
## field of its own and not [member counter_cost_kind]: that one is a
## fixed cost the ability cannot be activated without, and a mana planner
## that skips fixed counter costs must still count a battery as the one
## mana it always makes.
var any_number_counter_kind: String = ""
var bonus_per_counter: int = 0

## Fluent: let the activating player remove any number of [param kind]
## counters, each adding [param bonus] more of the first produced colour.
func with_any_number_of_counters(kind: String, bonus := 1) -> ManaAbility:
	any_number_counter_kind = kind
	bonus_per_counter = bonus
	return self


## "Reveal any number of <kind> cards in your hand. Add {C}{C} for each
## card revealed this way" (Metalworker — Pack 10 E8; CR 605.1a, 701.16a).
## [member reveal_filter] picks the hand cards that may be revealed
## ([code]func(card: CardInstance) -> bool[/code]); MtgGame.tap_for_mana
## asks the activating player HOW MANY (an OPTION "0".."N", hint N) and,
## when fewer than all, WHICH (one CARD question per card) — each held for
## a human seat like a battery's count — reveals them to every player and
## adds [member reveal_per_card] more of the first produced colour per card.
## Build the ability with an amount of 0 ([code]ManaAbility.new(C, 0)[/code]).
## ManaPlanner counts the seat's own maximum (its own hand — fair).
var reveal_filter: Callable = Callable()
var reveal_desc: String = ""
var reveal_per_card: int = 0

## Fluent: see [member reveal_filter]. [param desc] names the kind in the
## questions ("artifact": "Select artifact card to reveal.").
func with_reveal_from_hand(filter: Callable, desc: String, per_card := 2) -> ManaAbility:
	reveal_filter = filter
	reveal_desc = desc
	reveal_per_card = per_card
	return self

## The cards of [param hand] this ability may reveal. [param public_only]:
## only those already revealed — what ANOTHER seat may count (rule 8).
func reveal_candidates(hand: Array, public_only := false) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	if not reveal_filter.is_valid():
		return out
	for card: CardInstance in hand:
		if public_only and not card.revealed_in_hand:
			continue
		if bool(reveal_filter.call(card)):
			out.append(card)
	return out


## RESTRICTED output: "Spend this mana only to cast artifact spells"
## (Mishra's Workshop) / creature spells (Metamorphosis). "" = unrestricted.
## The key is matched against the spell being cast by MtgGame.
var restriction_key: String = ""

## Fluent: restrict what this ability's mana may be spent on.
func with_restriction(key: String) -> ManaAbility:
	restriction_key = key
	return self


## Add [param amount] of [param color] to [param pool], honouring
## [member restriction_key].
func _pour(pool: ManaPool, color: int, amount: int) -> void:
	if restriction_key == "":
		pool.add(color, amount)
	else:
		pool.add_restricted(color, amount, restriction_key)


## Add this ability's mana to [param pool].
func produce_into(pool: ManaPool) -> void:
	for pair in produces:
		_pour(pool, pair[0], pair[1])


## Add this ability's mana, consulting [member dynamic_amount] and
## [member dynamic_color] when set. [param forced_color] is the colour the
## activating player already chose ([member color_options]); -1 means nobody
## was asked. It is passed in rather than looked up here because the choice
## is made once, as the ability is activated, and asking again here would put
## the same question twice (docs/duel-todo.md §1.3).
## [param bonus] is extra mana of the first colour on top of the amount —
## what the counters a battery just spent bought ([member bonus_per_counter]
## times the count MtgGame.tap_for_mana was told).
func produce_into_for(pool: ManaPool, game: MtgGame, source: CardInstance,
		forced_color := -1, bonus := 0, actor := -1) -> void:
	if forced_color == -1 and bonus == 0 and not dynamic_amount.is_valid() \
			and not dynamic_color.is_valid():
		produce_into(pool)
		return
	var first_color: int = produces[0][0]
	if forced_color != -1:
		first_color = forced_color
	elif dynamic_color.is_valid():
		first_color = int(dynamic_color.call(game, source))
	var first_amount: int = produces[0][1]
	if dynamic_amount.is_valid():
		first_amount = amount_for(game, source, actor)
	_pour(pool, first_color, first_amount + bonus)
	for i in range(1, produces.size()):
		_pour(pool, produces[i][0], produces[i][1])


func _to_string() -> String:
	var parts := PackedStringArray()
	for pair in produces:
		parts.append("%d %s" % [pair[1], Mtg.COLOR_NAMES[pair[0]]])
	var costs := PackedStringArray()
	if cost != null and cost.text != "": costs.append(cost.text)
	if taps_source: costs.append("{T}")
	if sacrifice_source: costs.append("Sacrifice this permanent")
	if exile_source: costs.append("Exile this card from your hand")
	if sacrifice_filter.is_valid(): costs.append("Sacrifice " + sacrifice_filter_desc)
	if life_cost > 0: costs.append("Pay %d life" % life_cost)
	return ", ".join(costs) + ": Add " + ", ".join(parts)
