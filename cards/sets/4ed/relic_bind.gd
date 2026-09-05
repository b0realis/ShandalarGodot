extends CardScript
## Relic Bind — {2}{U} — Enchantment — Aura — (4ed, rare)
## Oracle: Enchant artifact an opponent controls
##         Whenever enchanted artifact becomes tapped, choose one —
##         • This Aura deals 1 damage to target player or planeswalker.
##         • Target player gains 1 life.
##
## Implementation: a BECAME_TAPPED trigger on the enchanted artifact that
## is both MODAL and TARGETED (TriggeredAbility.modal + targeting). As
## the trigger goes on the stack the Aura's controller announces the mode
## FIRST (CR 603.3c, 700.2d) and then names the target player (CR
## 603.3d) — both with the original's own strings (`@RELIC_BIND`,
## `Program/prompts.txt:746`: "Select target player." / "Gain life." /
## "Take damage."), a human seat being asked the moment a player would
## receive priority, the target as an OPTION list of the two names since
## a player is not a card. Either player is legal for either mode,
## yourself included: you may burn yourself or heal your opponent, as
## printed. The heuristic seat's and the AI's play is "Take damage." at
## the opponent — the mode hint and the target ranking — and that pair
## is the human seat's default highlight too. The mode and the target are
## then on the stack for the opponent to see before they respond, and
## the trigger resolves against them (MtgGame.current_mode /
## current_targets).
##
## The trigger reads the enchanted artifact live, so a Relic Bind whose host
## has gone (or has stopped being an artifact) simply never fires.


func build() -> CardData:
	return CardData.new("Relic Bind", "{2}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"enchant artifact an opponent controls", _is_artifact) \
			.with_source_filter(_theirs)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED, _bind,
			"Whenever enchanted artifact becomes tapped, choose one — this Aura deals 1 damage to target player, or target player gains 1 life.",
			_my_host) \
			.modal(["Gain life.", "Take damage."], _prefer_damage) \
			.targeting(TargetSpec.player(), _opponent_first,
				"Select target player.")) \
		.oracle("Enchant artifact an opponent controls\nWhenever enchanted artifact "
			+ "becomes tapped, choose one —\n• This Aura deals 1 damage to target "
			+ "player or planeswalker.\n• Target player gains 1 life.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


static func _theirs(_game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return source == null or inst.controller_id != source.controller_id


static func _my_host(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var tapped: CardInstance = event.data["instance"]
	return source.attached_to == tapped.id


## The modes, in the original's order (`@RELIC_BIND` entries 3-4).
const MODE_GAIN := 0
const MODE_DAMAGE := 1


## The controller's preferred mode: burn.
static func _prefer_damage(_game: MtgGame, _source: CardInstance,
		_event: GameEvent) -> int:
	return MODE_DAMAGE


## The opponent first.
static func _opponent_first(_game: MtgGame, source: CardInstance,
		a: TargetRef, b: TargetRef) -> bool:
	var a_enemy := a.player_id != source.controller_id
	var b_enemy := b.player_id != source.controller_id
	if a_enemy != b_enemy:
		return a_enemy
	return a.player_id < b.player_id


static func _bind(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var refs: Array = game.current_targets()
	if refs.is_empty():
		return
	var target: TargetRef = refs[0]
	if game.current_mode() == MODE_GAIN:
		game.adjust_life(target.player_id, 1)
	else:
		game.deal_damage(source, target, 1)
