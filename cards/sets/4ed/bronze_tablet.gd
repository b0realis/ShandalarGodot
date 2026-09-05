extends CardScript
## Bronze Tablet — {6} — Artifact — (4ed, rare)
## Oracle: Remove this card from your deck before playing if you're not
##         playing for ante.
##         This artifact enters tapped.
##         {4}, {T}: Exile this artifact and target nontoken permanent an
##         opponent owns. That player may pay 10 life. If they do, put this
##         card into its owner's graveyard. Otherwise, that player owns this
##         card and you own the other exiled card.
##
## The ransom is a real QUESTION, put to the victim through their own
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself.
##
## Implementation: the ransom is offered through the victim's DecisionAgent
## (hint: pay if 10 life still leaves you alive and the hostage is worth
## more than a Tablet). Both cards are exiled first — that is the printed
## order — and the settlement then either buries the Tablet or swaps the
## two cards' OWNERS, the permanent kind of change that outlives the duel.


static func _theirs_and_nontoken(_game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return not inst.is_token and inst.owner_id != source.controller_id


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target nontoken permanent an opponent owns")
	spec.with_source_filter(_theirs_and_nontoken)
	return CardData.new("Bronze Tablet", "{6}", Mtg.CardType.ARTIFACT) \
		.with_enters_tapped() \
		.activated(ActivatedAbility.new("{4}", true, [TabletEffect.new(spec)],
			"{4}, {T}: Exile this artifact and target nontoken permanent an opponent owns; that player may pay 10 life.")) \
		.oracle("Remove this card from your deck before playing if you're not playing for ante.\nThis artifact enters tapped.\n{4}, {T}: Exile this artifact and target nontoken permanent an opponent owns. That player may pay 10 life. If they do, put this card into its owner's graveyard. Otherwise, that player owns this card and you own the other exiled card.")


class TabletEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var hostage := game.find_instance(target.instance_id)
		if source == null or hostage == null or hostage.zone != Mtg.Zone.BATTLEFIELD:
			return
		var victim := hostage.owner_id
		game.exile_permanent(hostage)
		if source.zone == Mtg.Zone.BATTLEFIELD:
			game.exile_permanent(source)
		var hint: bool = game.players[victim].life > 10
		if game.agents[victim].choose_yes_no(game, victim,
				"Pay 10 life to keep %s?" % hostage.data.card_name, hint) \
				and game.players[victim].life >= 10:
			game.adjust_life(victim, -10)
			game.return_from_exile_to_graveyard(source)   # the Tablet is buried
			return
		game.change_owner(source, victim)
		game.change_owner(hostage, controller)

	func describe() -> String:
		return "exiles this and target nontoken permanent an opponent owns, for a 10-life ransom"
