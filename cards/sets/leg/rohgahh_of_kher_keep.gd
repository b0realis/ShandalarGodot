extends CardScript
## Rohgahh of Kher Keep — {2}{B}{B}{R}{R} — Legendary Creature — Kobold — 5/5 — (leg, rare)
## Oracle: At the beginning of your upkeep, you may pay {R}{R}{R}. If you
##         don't, tap Rohgahh and all creatures named Kobolds of Kher Keep,
##         then an opponent gains control of them.
##         Creatures you control named Kobolds of Kher Keep get +2/+2.
##
## Implementation: the anthem is a plain static keyed on the NAME (not the
## Kobold subtype — Crookshank Kobolds and Crimson Kobolds get nothing),
## and only on creatures Rohgahh's controller controls. The rent hands the
## whole Kobold army over when it goes unpaid: every creature named Kobolds
## of Kher Keep ON THE BATTLEFIELD, whoever controls it, plus Rohgahh
## itself, is tapped and then changes hands. In a two-player duel "an
## opponent" is the only opponent, so there is no choice to make.
##
## Kobolds of Kher Keep already in the opponent's hands stay there —
## change_control to their current controller is a no-op — but they are
## still tapped, exactly as printed.
##
## The rent is a real QUESTION, asked of the paying seat through its own
## DecisionAgent: the human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The `hint` below is
## only the default answer, not a decision the engine takes.


const KOBOLDS := "Kobolds of Kher Keep"


func build() -> CardData:
	return CardData.new("Rohgahh of Kher Keep", "{2}{B}{B}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(5, 5) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["kobold"]) \
		.static_ability(StaticAbility.new(
			_muster, "Creatures you control named Kobolds of Kher Keep get +2/+2.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _pay_the_rent,
			"At the beginning of your upkeep, you may pay {R}{R}{R}. If you don't, tap Rohgahh and all creatures named Kobolds of Kher Keep, then an opponent gains control of them.",
			_own_upkeep)) \
		.oracle("At the beginning of your upkeep, you may pay {R}{R}{R}. If you don't, tap "
			+ "Rohgahh and all creatures named Kobolds of Kher Keep, then an opponent gains "
			+ "control of them.\n"
			+ "Creatures you control named Kobolds of Kher Keep get +2/+2.")


static func _muster(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_creature() and inst.data.card_name == KOBOLDS:
			inst.cur_power += 2
			inst.cur_toughness += 2


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _pay_the_rent(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var rent := ManaCost.parse("{R}{R}{R}")
	if game.can_afford_cost(pid, rent) and game.agents[pid].choose_yes_no(
			game, pid, "Pay {R}{R}{R} to keep %s?" % source.data.card_name, true) \
			and game.try_pay(pid, rent):
		return
	var deserters: Array[CardInstance] = []
	if source.zone == Mtg.Zone.BATTLEFIELD:
		deserters.append(source)
	for inst in game.all_battlefield():
		if inst.is_creature() and inst.data.card_name == KOBOLDS:
			deserters.append(inst)
	var enemy := game.opponent_of(pid)
	for inst in deserters:
		game.tap_permanent(inst)
	for inst in deserters:
		if inst.controller_id != enemy:
			game.change_control(inst, enemy)
