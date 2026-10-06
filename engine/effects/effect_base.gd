class_name EffectBase
extends RefCounted
## Base class for one-shot effects — the things a spell or ability DOES when
## it resolves ("deal 3 damage", "draw three cards", "destroy target
## creature"...).
##
## Contract for subclasses:
## - Override [method resolve]. It receives the game (the only mutation
##   surface), the resolving source instance, the controller id, and the
##   chosen target (null when [member target_spec] is null).
## - If the effect targets, set [member target_spec] (usually via the
##   subclass's fluent helpers, e.g. [code]DamageEffect.new(3).any_target()[/code]).
##   MtgGame collects one target per targeting effect at cast time, validates
##   it, and re-validates at resolution.
## - Keep effects SMALL and composable: a card with two sentences of rules
##   text is usually two effects in sequence, not one big one. That is what
##   keeps card files readable and reusable.
##
## Continuous ("until end of turn"/static) changes are NOT EffectBase
## subclasses — they are floating effects registered through
## game.continuous (see PumpEffect for the bridge, and continuous.gd).

## What this effect targets, or null for untargeted effects.
var target_spec: TargetSpec = null

# ------------------------------------- the damage-prevention window (§6.8) --
# `Duel.hlp`, topic **Combat**: *"During damage dealing, players may use
# only damage prevention fast effects — those that prevent, heal, or
# redirect damage. (If a creature takes lethal damage or is destroyed,
# regeneration effects are allowed.) No other kind of fast effects or
# spells are permitted."* Under `RulesOptions.damage_prevention_window`
# the engine has to be able to tell those two families from everything
# else, and it is a DATA FLAG rather than a type switch so a card can opt
# in without the engine growing a list of card names.

## "Prevents, heals, or redirects damage" — legal in the damage-prevention
## window and nowhere special otherwise. Set in the constructors of the
## three prevention effects; a card whose own effect belongs to the family
## says so with [method as_damage_prevention]. `Duel.hlp` names four by
## hand: Reverse Damage, Reverse Polarity, Simulacrum and Personal
## Incarnation.
var is_damage_prevention: bool = false

## A REGENERATION effect, which `Duel.hlp` (topic **Regeneration**) is
## explicit is NOT a prevention effect: *"Nor is regeneration one of the
## damage prevention fast effects that you are allowed to use during
## damage prevention steps. You can use regeneration only at the time when
## a creature is about to go to the graveyard."* That moment is the SECOND
## window, and this flag is what may be used in it.
var is_regeneration: bool = false


## Fluent: mark this effect as one of the damage-prevention family (see
## [member is_damage_prevention]).
func as_damage_prevention() -> EffectBase:
	is_damage_prevention = true
	return self

## This effect's target may be DECLINED, and it does something sensible
## with none. Not the same as [member target_min] being 0 on its own: this
## says the effect is still worth resolving untargeted, so MtgGame neither
## counters the ability for "no legal targets" nor skips the effect.
##
## One user so far — the Circles of Protection, whose target is a DAMAGE
## PACKET and so exists only while a 1997 damage-prevention window is open
## (§6.8). With the fork off they take no target and put up the shield they
## always did.
var resolves_untargeted: bool = false


## Fluent: "target <spec>, or nothing at all" (see
## [member resolves_untargeted]).
func optional_target() -> EffectBase:
	target_min = 0
	target_max = 1
	resolves_untargeted = true
	return self


## This effect does its target GOOD — the AI's target picker aims helpful
## effects at itself and its own things and harmful ones at the opponent's
## ([method AiPlayer._is_harmful]), and it judges by effect class, so a
## card-local effect that helps (Drafna's Restoration puts YOUR artifacts
## back) says so here or is taken for removal.
var ai_helpful: bool = false

## Declarative shape of a card-local payload. Decisions consume these
## public effect parameters, never card names or hidden information.
var ai_role: StringName = &""
var ai_parameters: Dictionary = {}

func with_ai_role(role: StringName, parameters := {}) -> EffectBase:
	ai_role = role
	ai_parameters = parameters
	return self


## Fluent: this effect benefits what it targets (see [member ai_helpful]).
func helpful() -> EffectBase:
	ai_helpful = true
	return self

# ----------------------------------------------- variable target counts --
# An effect normally takes exactly ONE target. These three fields widen that
# to the whole 1997 pool's vocabulary, and TargetPlan turns them into the
# actual grouping of TargetRefs at cast/activation time:
#   "X target creatures"           → target_count_is_x = true
#   "one or more target creatures" → target_min 1, target_max -1
#   "any number of targets"        → target_min 0, target_max -1

## Minimum number of targets this effect demands (when target_spec is set).
var target_min: int = 1

## Maximum number of targets; -1 means "any number" (unbounded).
var target_max: int = 1

## "X target ..." — the count IS the spell's X (Word of Binding, Part Water,
## Volcanic Eruption, Candelabra of Tawnos). Overrides min/max.
var target_count_is_x: bool = false

## DIVIDED effects: the total to split among the chosen targets ("4 damage
## divided as you choose"). 0 = not divided. [member divided_uses_x] makes
## the total the spell's X instead (Fireball).
var divided_total: int = 0
var divided_uses_x: bool = false


## Fluent: "one or more target <spec>" — at least one, no upper bound.
func one_or_more() -> EffectBase:
	target_min = 1
	target_max = -1
	return self


## Fluent: "X target <spec>" — exactly X of them (as many as possible when
## fewer legal targets exist, CR 601.2c).
func x_targets() -> EffectBase:
	target_count_is_x = true
	return self


## Fluent: "<total> divided as you choose among any number of targets".
## Pass -1 for [param total] to divide the spell's X instead (Fireball).
func divided_among(total: int) -> EffectBase:
	divided_uses_x = total < 0
	divided_total = maxi(total, 0)
	target_min = 1
	target_max = -1
	return self


## How many targets this effect needs, as Vector2i(min, max); max of -1
## means unbounded. [param x_value] is the spell's X.
func target_range(x_value: int) -> Vector2i:
	if target_spec == null:
		return Vector2i.ZERO
	if target_count_is_x:
		return Vector2i(x_value, x_value)
	return Vector2i(target_min, target_max)


## The total a DIVIDED effect splits among its targets (0 = not divided).
func divided_amount(x_value: int) -> int:
	if divided_uses_x:
		return x_value
	return divided_total


# ------------------------------- Pack 9 E7: a target count fixed by a target --

## A target COUNT that ANOTHER target of the same spell or ability decides
## (CR 601.2c — the number of targets is chosen with them): "Return up to X
## target cards from your graveyard to your hand, where X is the number of
## black permanents target opponent controls as you cast this spell" (Reap).
## [code]func(game: MtgGame, source: CardInstance, earlier: Array) ->
## Vector2i[/code] — (min, max), max -1 = any number — where `earlier` is
## the refs of the targeting effects BEFORE this one, in order. So the
## slot it reads must come first, and every slot before this one must
## take a fixed number of targets (with a variable one before it the refs
## are not known, and `earlier` is empty). Read by TargetPlan as the spell
## or ability is announced; the count is fixed then and never re-read at
## resolution. Unset = [method target_range]. Set with
## [method targets_counted_by].
var target_count_fn: Callable = Callable()


## Fluent: this effect's target count is [param fn]'s (see
## [member target_count_fn]). The STATIC range becomes "any number"
## (0..-1), which is what a reader that cannot see the earlier targets
## ([method target_range]) offers — [method target_range_at] is the exact
## one.
func targets_counted_by(fn: Callable) -> EffectBase:
	target_count_fn = fn
	target_min = 0
	target_max = -1
	return self


## The target range once the EARLIER targeting effects' refs are known —
## [param earlier], in effect order (see [member target_count_fn]). Equal
## to [method target_range] for every effect without a count function. A
## new method rather than a parameter on [method target_range]: card
## scripts override this class's methods.
func target_range_at(game: MtgGame, source: CardInstance, x_value: int,
		earlier: Array) -> Vector2i:
	if target_spec == null:
		return Vector2i.ZERO
	if not target_count_fn.is_valid():
		return target_range(x_value)
	var span: Vector2i = target_count_fn.call(game, source, earlier)
	var lo := maxi(0, span.x)
	return Vector2i(lo, span.y if span.y < 0 else maxi(lo, span.y))


## Apply the effect. [param target] is the validated TargetRef chosen for
## this effect (null if untargeted); [param x_value] is the X chosen at cast
## time for {X} spells (0 otherwise — effects that scale with X read it, all
## others ignore it). Mutate the game ONLY through MtgGame's public mutation
## helpers so every change is logged and SBA-checked.
func resolve(_game: MtgGame, _source: CardInstance, _controller: int, _target: TargetRef,
		_x_value: int = 0) -> void:
	push_error("EffectBase.resolve not overridden in %s" % get_script().resource_path)


## Apply the effect to a GROUP of targets — the entry point MtgGame uses.
## The default repeats [method resolve] once per target, which is exactly
## right for "Tap X target creatures" / "X target creatures gain islandwalk"
## and identical to the old behavior for single-target effects. Effects that
## must see the whole group at once (divided damage) override this.
## [param targets] may be empty for untargeted effects.
func resolve_multi(game: MtgGame, source: CardInstance, controller: int,
		targets: Array, x_value: int = 0) -> void:
	if targets.is_empty():
		resolve(game, source, controller, null, x_value)
		return
	for t in targets:
		resolve(game, source, controller, t, x_value)


# --------------------------------------------- "unless a player pays" (CR 118.12) --
#
# *"Some spells, activated abilities, and triggered abilities read, '[Do
# something] unless [a player does something else].' This means the player
# has the option to take the specified action... If they don't, the first
# action is taken"* — CR 118.12. Forty-two cards in this pool print one
# (45 sites), and until 2026-09-10 every single one of them wrote the same
# three-clause chain by hand: can the payer afford it, will they, did the
# payment go through. [method unless_paid] is that chain, once.
#
# WHY IT IS STATIC, and it matters: most of the pool's "unless" clauses are
# not on an effect at all but on an UPKEEP TRIGGER (Force of Nature, Junún
# Efreet, Cyclone, Stasis, Demonic Hordes, Sunken City, Primordial Ooze,
# Cosmic Horror, The Tabernacle at Pendrell Vale…), whose callback is a
# plain static function with no EffectBase in reach. A static helper serves
# both doors from one body; `EffectBase.unless_paid(game, …)` from a
# trigger reads a little oddly and is the price of having ONE of these.
# (The plan that asked for it — docs/forge/rules.md §4.5 — imagined a
# fluent rider beside `optional_target`; the pool's own shape is why this
# is a call instead. A rider would have to name the payer, and the payer is
# the source's controller on the upkeep taxes, the TARGET'S controller on
# Power Sink, and the caster on Nether Void.)
#
# The three clauses, in the order they must run:
#  * [method MtgGame.can_afford_cost] first, so a seat that cannot pay is
#    never asked a question with no answer (and no PlayerChoice is filed
#    for one);
#  * the payer's own [DecisionAgent], so a human seat is held open on it
#    (docs/duel-todo.md §1.3) and the AI answers for itself. `hint` is the
#    default answer, never a decision the engine takes;
#  * [method MtgGame.try_pay] last, and its FALSE is a real answer: a plan
#    that goes stale mid-payment leaves the cost unpaid, and the "[do
#    something]" half must then happen.

## "…unless [param payer] pays [param cost]". Returns TRUE when the payer
## paid — the caller's "unless" branch, in which the printed action does
## NOT happen — and FALSE when they could not, would not, or the payment
## failed. [param prompt] is the question in the card's own words;
## [param hint] is what the heuristic would answer.
static func unless_paid(game: MtgGame, payer: int, cost: ManaCost,
		prompt: String, hint := true) -> bool:
	if not game.can_afford_cost(payer, cost):
		return false
	if not game.agents[payer].choose_yes_no(game, payer, prompt, hint):
		return false
	return game.try_pay(payer, cost)


## One-line description for logs and UI ("deals 3 damage to any target").
func describe() -> String:
	return "does something"
