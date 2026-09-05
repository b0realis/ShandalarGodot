class_name StackItem
extends RefCounted
## One object on the stack: a spell being cast, an activated ability, or a
## triggered ability waiting to resolve.
##
## The stack itself is just [code]MtgGame.stack: Array[StackItem][/code]
## (index 0 = bottom; the last element is the top and resolves first).
## Resolution logic lives in MtgGame._resolve_top; this class only carries
## the data a pending object needs:
## - SPELL: [member card] is the cast card (physically in Mtg.Zone.STACK);
##   [member effects] are its CardData.spell_effects (or the chosen mode's,
##   for a modal card); [member targets] is the flat list of chosen targets
##   and [member target_groups] the same refs sliced per targeting effect.
## - ABILITY: [member card] is the battlefield source; effects/targets as
##   above (from the ActivatedAbility).
## - TRIGGER: [member trigger] + [member event] capture the triggered
##   ability and the event that fired it. The context-only majority choose
##   no targets, so both target fields stay empty; a trigger built with
##   [method TriggeredAbility.targeting] carries its one chosen target in
##   both, exactly as a single-target ability does (CR 603.3d).

## Unique id, handed out by MtgGame as the item goes on the stack. An
## ABILITY has no card of its own — several activations of one permanent can
## be on the stack at once — so this is what a [TargetRef] names when a card
## targets an ability ("counter target activated ability" — Rust, Ayesha
## Tanaka). 0 for an item nobody numbered (a test building one by hand).
var id: int = 0

## One of Mtg.StackKind.
var kind: int

## The card being cast (SPELL) or the ability's source (ABILITY/TRIGGER).
var card: CardInstance

## Player who put this on the stack and will resolve it.
var controller: int

## Effects to run on resolution (SPELL and ABILITY kinds).
var effects: Array[EffectBase] = []

## Chosen targets, FLAT, in effect order (one per targeting effect for the
## single-target majority). The UI and the fizzle check read this.
var targets: Array[TargetRef] = []

## The same refs GROUPED per targeting effect — one Array[TargetRef] per
## targeting effect, produced by TargetPlan at cast/activation time. This is
## what makes "Tap X target creatures" and "4 damage divided as you choose"
## resolvable; single-target effects get one-element groups. Empty for
## triggers (which carry no chosen targets).
var target_groups: Array = []

## TRIGGER kind: the triggered ability and the event that fired it. The
## event is carried, not re-derived, so "that land's controller" (Ankh of
## Mishra) still answers correctly when the trigger resolves several
## priority passes later — last known information, CR 608.2h.
var trigger: TriggeredAbility = null
var event: GameEvent = null
## TRIGGER kind, for a DELAYED triggered ability (CR 603.7): the queue
## entry it came from — [member MtgGame.delayed_triggers] — whose
## `memory` the resolution reads through MtgGame.current_delayed. Empty
## for every trigger a permanent carries.
var delayed: Dictionary = {}

## TRIGGER kind, targeted or modal: true while the controller's SEAT has
## still to name the target (and, for a modal trigger, announce the mode).
## The trigger went on the stack inside some mutation (a creature died, a
## step began) with a provisional pick in [member targets] / [member mode];
## the moment a player would receive priority (CR 603.3)
## MtgGame._hold_trigger_targets puts the question(s) to the seat and
## replaces the pick. Only a seat that wants to be asked (the human) is
## ever held — every other seat answered as the trigger went on the stack.
var target_held: bool = false

## For {X} spells: the chosen X value (0 otherwise).
var x_value: int = 0

## For modal spells: which mode was chosen at cast time. For a modal
## TRIGGER (TriggeredAbility.modal): the mode announced as it went on the
## stack (CR 603.3c), read on resolution through MtgGame.current_mode.
var mode: int = 0

## WHAT THIS ACTIVATION'S COST ATE — `_sacrificed_toughness`,
## `_exiled_mana_value`, `_discarded_types` and the names beside them,
## snapshotted as the cost was paid (CR 608.2h last known information) for
## the ability's own effects to read on resolution: *"You gain life equal
## to the sacrificed creature's toughness"* (Diamond Valley, Life Chisel),
## Necropolis' X, Land's Edge's card type.
##
## ON THE ITEM, NOT ON THE PERMANENT, and that is the whole point. These
## records used to live in `CardInstance.memory`, which is ONE slot per
## permanent — so two free activations of the same permanent stacked on top
## of each other read each other's record. Every one of the four cards
## above has a free or nearly free activation cost, so stacking two is a
## normal line and not a corner case: Life Chisel with two creatures
## sacrificed in response to each other gained the SECOND body's toughness
## twice. Found by the 2026-09-01 card audit, fixed 2026-09-02.
##
## A SPELL does not need this and does not use it (`sacrificed_mv` still
## lives on the spell's own memory): a card instance is on the stack at
## most once, so its own memory is already per-cast. An ABILITY has no card
## of its own, which is exactly why [member id] exists too.
##
## Read through [method MtgGame.cost_paid] rather than off this field, so a
## card never has to find the item it is resolving inside.
var cost_paid: Dictionary = {}

## Log/UI description, filled at creation ("Lightning Bolt targeting p1").
var description: String = ""


func _to_string() -> String:
	return description
