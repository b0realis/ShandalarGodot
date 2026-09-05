class_name SearchLibraryEffect
extends EffectBase
## "Search your library for a [filtered] card, put it into your hand, then
## shuffle." — Demonic Tutor's payload.
##
## The CHOICE goes through the controller's DecisionAgent
## (MtgGame.search_library): the AI evaluates candidates; the human seat's
## UI pre-selects before casting (DuelScreen detects this effect class and
## opens the library picker first). [member filter] narrows candidates
## (null = any card); [member description] is card English for prompts.

## Narrows the candidates, func(inst: CardInstance) -> bool. Unset = any
## card (Demonic Tutor); Untamed Wilds passes a basic-land predicate.
var filter: Callable = Callable()

## Card-English name of what is being searched for, used verbatim in the
## agent prompt and in [method describe].
var description: String = "a card"

## When true the found card enters the BATTLEFIELD, not the hand
## (Untamed Wilds).
var battlefield: bool = false


func _init(p_description := "a card", p_filter: Callable = Callable()) -> void:
	description = p_description
	filter = p_filter


## Fluent: put the found card onto the battlefield.
func to_battlefield() -> SearchLibraryEffect:
	battlefield = true
	return self


## Delegates the whole thing to MtgGame.search_library: it asks the
## controller's DecisionAgent to pick, moves the card library → hand (or
## battlefield), and shuffles afterwards. Untargeted and controller-only —
## no card in this pool searches an opponent's library.
func resolve(game: MtgGame, _source: CardInstance, controller: int, _target: TargetRef,
		_x_value: int = 0) -> void:
	game.search_library(controller, filter,
		"Search your library for %s" % description, battlefield)


## One-line log/UI text.
func describe() -> String:
	var dest := "onto the battlefield" if battlefield else "into your hand"
	return "search your library for %s, put it %s, then shuffle" % [description, dest]
