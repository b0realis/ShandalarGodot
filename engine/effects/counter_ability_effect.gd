class_name CounterAbilityEffect
extends EffectBase
## "Counter target activated ability." — Rust, Ayesha Tanaka.
##
## The sibling of [CounterEffect], for the other kind of object that sits on
## the stack. An ability is not a card (CR 113.3b): countering it removes
## its [StackItem] and nothing goes anywhere, because there is no card to
## put in a graveyard, and any cost already paid for it stays paid.
##
## The printed "(Mana abilities can't be targeted.)" needs no code — a mana
## ability never uses the stack at all (CR 605.3a), so it is never a
## candidate for [constant TargetSpec.Kind.ABILITY].
##
## [member unless_cost] is Ayesha Tanaka's "unless that ability's controller
## pays {W}": the ability's own controller is offered the ransom on
## resolution, and the counter happens only if they decline or cannot pay.

## The ransom the ability's controller may pay to save it, or null.
var unless_cost: ManaCost = null


func _init(desc: String = "", filter: Callable = Callable()) -> void:
	target_spec = TargetSpec.activated_ability(desc, filter)


## Fluent: "...unless that ability's controller pays [param cost]".
func unless_they_pay(cost: String) -> CounterAbilityEffect:
	unless_cost = ManaCost.parse(cost)
	return self


func resolve(game: MtgGame, _source: CardInstance, _controller: int,
		target: TargetRef, _x_value: int = 0) -> void:
	var item := game.find_stack_ability(target.ability_id)
	if item == null:
		return   # it resolved or was countered first — nothing to do
	if unless_cost != null:
		var payer := item.controller
		if game.can_afford_cost(payer, unless_cost) \
				and game.agents[payer].choose_yes_no(game, payer,
					"Pay %s to save %s?" % [unless_cost.text, item.description],
					true) \
				and game.try_pay(payer, unless_cost):
			game.log_line("%s pays %s and keeps the ability" % [
				game.players[payer].player_name, unless_cost.text])
			return
	game.counter_ability(target.ability_id)


## Is [param item] an activated ability from an ARTIFACT source? The filter
## both Rust and Ayesha Tanaka carry, in one place.
static func from_an_artifact(item: StackItem) -> bool:
	return item.card != null and item.card.is_type(Mtg.CardType.ARTIFACT)


func describe() -> String:
	return "counters %s" % target_spec.description
