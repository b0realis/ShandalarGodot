class_name CounterEffect
extends EffectBase
## "Counter target spell." — Counterspell.
##
## Targets a card in Mtg.Zone.STACK (TargetSpec.Kind.SPELL). Resolution
## calls MtgGame.counter_spell, which removes the spell's StackItem and puts
## the card into its owner's graveyard (CR 701.5a). If the target spell has
## already resolved (or was itself countered), the target is illegal at
## resolution and this spell fizzles — the engine's standard CR 608.2b path,
## nothing special needed here.


var destination: int = Mtg.Zone.GRAVEYARD
## With [member destination] BATTLEFIELD: the Mtg.CardType flags a
## countered spell must have to change sides (Desertion: artifact or
## creature); any other spell goes to its owner's graveyard as usual.
var battlefield_types: int = 0

func to_library_top() -> CounterEffect:
	destination = Mtg.Zone.LIBRARY
	return self

## "If that spell is countered this way, exile it instead of putting it
## into its owner's graveyard" (Dissipate).
func to_exile() -> CounterEffect:
	destination = Mtg.Zone.EXILE
	return self

## "If an artifact or creature spell is countered this way, put that card
## onto the battlefield under your control instead of into its owner's
## graveyard" (Desertion). "Your" is this counterspell's controller; the
## card ENTERS the battlefield (MtgGame.counter_spell). The type test reads
## the spell as it was on the stack.
func to_battlefield_for_caster(types := Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) -> CounterEffect:
	destination = Mtg.Zone.BATTLEFIELD
	battlefield_types = types
	return self

func _init(desc: String = "", filter: Callable = Callable()) -> void:
	target_spec = TargetSpec.spell(desc, filter)

## Some counters may legally target a spell without affecting it
## (Hydroblast/Pyroblast). The AI must distinguish that from legality.
func affects_spell(_inst: CardInstance) -> bool:
	return true


## Removes the target's StackItem and moves the card to its owner's
## graveyard, both through MtgGame.counter_spell. The null guard is for a
## spell that is already gone (Fork's copy ceasing to exist, CR 707.10a):
## nothing to counter, and countering nothing is legal.
func resolve(game: MtgGame, _source: CardInstance, controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var inst := game.find_instance(target.instance_id)
	if inst == null:
		return
	if destination == Mtg.Zone.BATTLEFIELD:
		if (inst.data.types & battlefield_types) != 0:
			game.counter_spell(inst, Mtg.Zone.BATTLEFIELD, controller)
		else:
			game.counter_spell(inst)
		return
	game.counter_spell(inst, destination)


## One-line log/UI text.
func describe() -> String:
	return "counters %s" % target_spec.description
