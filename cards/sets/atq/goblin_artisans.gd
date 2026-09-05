extends CardScript
## Goblin Artisans — {R} — Creature — Goblin Artificer — 1/1 — (atq, uncommon)
## Oracle: {T}: Flip a coin. If you win the flip, draw a card. If you lose
##         the flip, counter target artifact spell you control that isn't
##         the target of an ability from another creature named Goblin
##         Artisans.
##
## Implementation: the coin is MtgGame.flip_coin (seeded through game.rng,
## so a duel replays), and the target is chosen at ACTIVATION as always —
## which is why the ability is only worth activating with an artifact spell
## of your own on the stack, exactly as printed. Losing the flip eats it.
##
## "That isn't the target of an ability from another Goblin Artisans" is a
## TARGETING restriction, so it lives in the TargetSpec: the spec walks the
## stack for another Artisans' ability already aimed at the same spell. That
## is what stops two Artisans from being a free 50/50 with no downside, and
## it is the reason this card is remembered at all.
##
## `@GOBLIN_ARTISANS`, `Program/promptsX1.txt:187`, is the flip itself:
## `Call the coin flip:` / `Heads.` / `Tails.`


func build() -> CardData:
	return CardData.new("Goblin Artisans", "{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["goblin", "artificer"]) \
		.activated(ActivatedAbility.new("", true, [TinkerEffect.new()],
			"{T}: Flip a coin. If you win the flip, draw a card. If you lose the flip, counter target artifact spell you control.")) \
		.oracle("{T}: Flip a coin. If you win the flip, draw a card. If you lose "
			+ "the flip, counter target artifact spell you control that isn't the "
			+ "target of an ability from another creature named Goblin Artisans.")


class TinkerEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell(
			"target artifact spell you control that isn't the target of an ability from another Goblin Artisans",
			TinkerEffect._is_artifact_spell) \
			.with_source_filter(TinkerEffect._yours_and_unclaimed)

	static func _is_artifact_spell(inst: CardInstance) -> bool:
		return inst.data.is_type(Mtg.CardType.ARTIFACT)

	## "You control" plus the printed exclusion: no OTHER Goblin Artisans'
	## ability may already be aimed at this spell.
	static func _yours_and_unclaimed(game: MtgGame, source: CardInstance,
			inst: CardInstance) -> bool:
		if source != null and inst.controller_id != source.controller_id:
			return false
		for item in game.stack:
			if item.kind != Mtg.StackKind.ABILITY or item.card == null:
				continue
			if item.card == source or item.card.data.card_name != "Goblin Artisans":
				continue
			for ref in item.targets:
				if not ref.is_player and not ref.is_damage \
						and not ref.is_ability and ref.instance_id == inst.id:
					return false
		return true

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		# `@GOBLIN_ARTISANS`, Program/promptsX1.txt:189.
		if game.flip_coin(controller):
			game.draw_cards(controller, 1)
			return
		if source != null:
			game.log_line("%s loses the flip" % source.data.card_name)
		var spell := game.find_instance(target.instance_id)
		if spell != null and spell.zone == Mtg.Zone.STACK:
			game.counter_spell(spell)

	func describe() -> String:
		return "flip a coin: draw a card, or counter your own artifact spell"
