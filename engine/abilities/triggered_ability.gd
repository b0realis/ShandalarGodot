class_name TriggeredAbility
extends RefCounted
## A triggered ability: "When/Whenever/At [event], [effect]." — e.g. Ankh of
## Mishra's "Whenever a land enters the battlefield, Ankh of Mishra deals 2
## damage to that land's controller."
##
## How triggering works (mirrors CR 603):
## 1. MtgGame.dispatch_event offers every GameEvent to every triggered
##    ability on every battlefield permanent.
## 2. [member event_type] must match, then [member condition] (if set) is
##    consulted: [code]func(game, source, event) -> bool[/code].
## 3. A matching trigger becomes a StackItem of kind TRIGGER on the stack
##    (active player's triggers go on first, so the non-active player's
##    resolve first — APNAP, CR 603.3b) and resolves via [member on_resolve]:
##    [code]func(game, source, event) -> void[/code].
##
## The resolve callable receives the ORIGINAL event, so effects like Ankh's
## "that land's controller" read their context directly from event.data.
## Most triggers are context-only: the ones that read as targeted resolve
## against the object the event already names.
##
## A trigger that TARGETS ("When this enchantment enters, target creature
## phases out" — Oubliette; "target non-Wall creature an opponent controls
## gains forestwalk" — Erhnam Djinn) declares its one target with
## [method targeting]. The engine then follows CR 603.3d: the target is
## chosen by the trigger's controller AS THE TRIGGER GOES ON THE STACK
## (MtgGame._arm_trigger_targets — a heuristic or AI seat answers on the
## spot, a human seat is held open on the question the moment a player
## would receive priority, CR 603.3), a trigger with no legal target is
## removed from the stack instead of going on it, and on resolution a
## target that has become illegal makes the trigger fizzle (CR 608.2b)
## without [member on_resolve] ever being called. The chosen target is what
## [method MtgGame.current_targets] returns while on_resolve runs.
##
## A trigger with MODES ("Whenever enchanted artifact becomes tapped,
## choose one — ..." — Relic Bind) declares them with [method modal]. The
## mode is announced by the controller as the trigger goes on the stack,
## BEFORE its target (CR 603.3c, 700.2d), through the same seat flow, and
## is what [method MtgGame.current_mode] returns while on_resolve runs.
## The one target spec is shared by every mode — enough for the pool.
##
## Where a trigger listens from: the battlefield by default
## (CardData.triggered_abilities), or a graveyard for the upkeep/end-step
## crawlers (CardData.graveyard_triggers — Nether Shadow). Same class either
## way; only the list a card registers it in differs.

## Which Mtg.EventType wakes this ability up.
var event_type: int

## Optional extra condition: func(game: MtgGame, source: CardInstance,
## event: GameEvent) -> bool. Unset = always fires on a type match.
var condition: Callable = Callable()

## What happens on resolution: func(game: MtgGame, source: CardInstance,
## event: GameEvent) -> void. Mutate only through MtgGame helpers.
var on_resolve: Callable

## Card-English text of the trigger, for logs and UI.
var text: String = ""

## Mana triggers (Mana Flare, Wild Growth) resolve IMMEDIATELY instead of
## using the stack — matching CR 605.1b's triggered mana abilities, and
## essential so their mana is usable mid-payment. Set via [method as_mana_trigger].
var is_mana_trigger: bool = false

## The trigger's ONE target, or null for the context-only majority. Set by
## [method targeting]; read by MtgGame as the trigger goes on the stack
## (CR 603.3d) and again as it resolves (CR 608.2b).
var target_spec: TargetSpec = null

## The controller's PREFERENCE among the legal targets:
## func(game: MtgGame, source: CardInstance, a: TargetRef, b: TargetRef)
## -> bool, "a before b". The list is sorted with it before the seat is
## asked, so its first entry is the heuristic seat's answer, the AI's pick
## and the human seat's default highlight — the same contract
## TargetSpec.opponent_chooses gives an opponent's choice. Unset: the
## engine's own battlefield order.
var target_order: Callable = Callable()

## The line the seat is asked with — the original's own prompt where one
## survives (`@OUBLIETTE`: "Select a creature."). "" builds one from the
## spec's description.
var target_prompt: String = ""


## Fluent: this trigger TARGETS. [param spec] is the target; [param order]
## and [param prompt] as documented on [member target_order] and
## [member target_prompt].
func targeting(spec: TargetSpec, order: Callable = Callable(),
		prompt: String = "") -> TriggeredAbility:
	target_spec = spec
	target_order = order
	target_prompt = prompt
	return self


## The modes of a modal trigger ("choose one —"), as the labels the seat
## is offered — the original's own where they survive (`@RELIC_BIND`:
## "Gain life." / "Take damage."). Empty for the non-modal majority.
var modes: Array[String] = []

## The controller's PREFERRED mode: func(game: MtgGame, source:
## CardInstance, event: GameEvent) -> int, an index into [member modes].
## The heuristic seat's answer, the AI's pick and the human seat's default
## highlight. Unset: the first mode.
var mode_hint: Callable = Callable()

## The line the seat is asked the mode with; "" builds "<name>: choose one".
var mode_prompt: String = ""


## Fluent: this trigger is MODAL. [param labels], [param hint] and
## [param prompt] as documented on [member modes], [member mode_hint] and
## [member mode_prompt].
func modal(labels: Array[String], hint: Callable = Callable(),
		prompt: String = "") -> TriggeredAbility:
	modes = labels
	mode_hint = hint
	mode_prompt = prompt
	return self


## Fluent: mark this as a triggered MANA ability (off-stack, instant resolve).
func as_mana_trigger() -> TriggeredAbility:
	is_mana_trigger = true
	return self


func _init(p_event_type: int, p_on_resolve: Callable, p_text: String = "",
		p_condition: Callable = Callable()) -> void:
	event_type = p_event_type
	on_resolve = p_on_resolve
	text = p_text
	condition = p_condition


## Does this ability trigger on [param event] from [param source]?
func matches(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	if event.type != event_type:
		return false
	if condition.is_valid():
		return condition.call(game, source, event)
	return true


func _to_string() -> String:
	return text if text != "" else "triggered ability"
