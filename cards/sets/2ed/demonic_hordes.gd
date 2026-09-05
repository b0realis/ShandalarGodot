extends CardScript
## Demonic Hordes — {3}{B}{B}{B} — Creature — Demon — 5/5 — (2ed, rare)
## Oracle: {T}: Destroy target land.
##         At the beginning of your upkeep, unless you pay {B}{B}{B}, tap
##         this creature and sacrifice a land of an opponent's choice.
##
## Implementation: both halves. The rent goes through the engine's usual
## "unless you pay" path, and failing it really does tap the Hordes AND eat
## one of your own lands — the drawback that keeps a 5/5 for six honest.
##
## The rent is a real QUESTION, asked of the paying seat through its own
## DecisionAgent: the human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The `hint` below is
## only the default answer, not a decision the engine takes.
##
## The land is the OPPONENT's pick, asked of their agent — see `_the_tithe`.


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


func build() -> CardData:
	return CardData.new("Demonic Hordes", "{3}{B}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(5, 5) \
		.with_subtypes(["demon"]) \
		.activated(ActivatedAbility.new("", true,
			[DestroyEffect.new(TargetSpec.new(
				TargetSpec.Kind.PERMANENT, "target land", _is_land))],
			"{T}: Destroy target land.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _the_tithe,
			"At the beginning of your upkeep, unless you pay {B}{B}{B}, tap this creature and sacrifice a land.",
			_your_upkeep)) \
		.oracle("{T}: Destroy target land.\nAt the beginning of your upkeep, unless you pay {B}{B}{B}, tap this creature and sacrifice a land of an opponent's choice.")


static func _your_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _the_tithe(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	# CR 603.6: the trigger resolves even if the Hordes has already left —
	# sacrificing it in response must not refund the land. Force of Nature
	# in the same set documents the same rule.
	var pid := int(event.data["player"])
	var rent := ManaCost.parse("{B}{B}{B}")
	if game.can_afford_cost(pid, rent) and game.agents[pid].choose_yes_no(
			game, pid, "Pay {B}{B}{B} to keep the Hordes free?", true) \
			and game.try_pay(pid, rent):
		return
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.tap_permanent(source)
	# "...sacrifice a land OF AN OPPONENT'S CHOICE" — theirs to pick, so it
	# is their agent that is asked, with the candidates sorted from THEIR
	# point of view: the land that hurts most goes first.
	var lands: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_land():
			lands.append(inst)
	if lands.is_empty():
		return
	lands.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return DemonicHordesSort.value(a) > DemonicHordesSort.value(b))
	var enemy := game.opponent_of(pid)
	var picked := game.agents[enemy].choose_card(game, enemy, lands,
		"Choose a land for %s's controller to sacrifice"
			% source.data.card_name)
	if picked == null or not lands.has(picked):
		picked = lands[0]
	game.sacrifice_permanent(picked)


## How much an opponent would like to see this land go: a nonbasic (or an
## enchanted one) is worth more than a Forest.
class DemonicHordesSort:
	static func value(inst: CardInstance) -> int:
		var score := 0
		if (inst.data.supertypes & Mtg.Supertype.BASIC) == 0:
			score += 10
		score += inst.attachments.size() * 2
		if not inst.tapped:
			score += 1
		return score
