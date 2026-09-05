extends CardScript
## Mana Vault — {1} — Artifact — (2ed, rare)
## Oracle: This artifact doesn't untap during your untap step.
##         At the beginning of your upkeep, you may pay {4}. If you do,
##         untap this artifact.
##         At the beginning of your draw step, if this artifact is tapped,
##         it deals 1 damage to you.
##         {T}: Add {C}{C}{C}.
##
## Implementation: cur_skips_untap static + ManaAbility {C}{C}{C} + two
## own-turn triggers: the upkeep {4} offer (try_pay) and the draw-step
## burn while tapped. The burn rides the DRAW_STEP event, which fires
## just after the turn's draw — and that IS the rules order, not a
## shortcut: the draw is a turn-based action taken before any player
## would receive priority (CR 504.1), and a "beginning of your draw step"
## trigger is put on the stack the next time a player would receive
## priority, i.e. after the draw (CR 603.3, 503.1a). A player who draws
## from an empty library loses to state-based actions before the burn
## can resolve (CR 704.5b), which is what happens at the table too.


func build() -> CardData:
	return CardData.new("Mana Vault", "{1}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(
			_lock, "This artifact doesn't untap during your untap step.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _offer_untap,
			"At the beginning of your upkeep, you may pay {4}. If you do, untap this artifact.",
			_own_upkeep)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DRAW_STEP, _burn_if_tapped,
			"At the beginning of your draw step, if this artifact is tapped, it deals 1 damage to you.",
			_own_draw)) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 3)) \
		.oracle("This artifact doesn't untap during your untap step.\nAt the beginning of your upkeep, you may pay {4}. If you do, untap this artifact.\nAt the beginning of your draw step, if this artifact is tapped, it deals 1 damage to you.\n{T}: Add {C}{C}{C}.")


static func _lock(_game: MtgGame, source: CardInstance) -> void:
	source.cur_skips_untap = true


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id


## "At the beginning of your draw step, IF THIS ARTIFACT IS TAPPED" — an
## intervening "if" (CR 603.4), so the tapped state is tested when the
## ability would trigger as well as on resolution. An untapped Vault does
## not go on the stack at all, and tapping it in response can no longer
## make a trigger that should never have existed burn its controller.
static func _own_draw(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id and source.tapped


static func _offer_untap(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD or not source.tapped:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{4}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {4} to untap %s?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		game.untap_permanent(source)


static func _burn_if_tapped(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD and source.tapped:
		game.deal_damage(source, TargetRef.player(source.controller_id), 1)
