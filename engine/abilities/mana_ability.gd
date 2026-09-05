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

## When true the cost also includes sacrificing the source (Black Lotus's
## "{T}, Sacrifice Black Lotus: Add three mana of any one color" — modeled
## as five sacrifice ManaAbilities, one per color, chosen by ability index).
## MtgGame.tap_for_mana performs the sacrifice after producing the mana.
var sacrifice_source: bool = false

## Optional MANA part of the cost ("{2}, {T}: Add one mana of any color"
## — Celestial Prism; Coal Golem's {3}). Paid from the FLOATING pool only
## (mana abilities resolve mid-payment; no auto-tapping here). Null =
## free.
var cost: ManaCost = null

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

## Fluent: compute the amount at activation time (see [member dynamic_amount]).
func with_dynamic_amount(cb: Callable) -> ManaAbility:
	dynamic_amount = cb
	return self


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
		forced_color := -1, bonus := 0) -> void:
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
		first_amount = int(dynamic_amount.call(game, source))
	_pour(pool, first_color, first_amount + bonus)
	for i in range(1, produces.size()):
		_pour(pool, produces[i][0], produces[i][1])


func _to_string() -> String:
	var parts := PackedStringArray()
	for pair in produces:
		parts.append("%d %s" % [pair[1], Mtg.COLOR_NAMES[pair[0]]])
	return "{T}: Add " + ", ".join(parts)
