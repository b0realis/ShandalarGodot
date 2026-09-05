extends CardScript
## Dark Sphere — {0} — Artifact — (drk, uncommon)
## Oracle: {T}, Sacrifice this artifact: The next time a source of your
##         choice would deal damage to you this turn, prevent half that
##         damage, rounded down.
##
## Implementation: the same one-shot player-side replacement Forcefield
## uses (MtgPlayer.damage_replacements), with a halving handler. "Rounded
## DOWN" is prevention rounded down, so an odd amount leaves the extra
## point coming at you — 5 damage becomes 3, not 2.
##
## "A source of your choice" is chosen when the ability resolves, and the
## choices offered are the opponent's permanents plus whatever is on the
## stack, which is every source that can actually be pointed at you.
##
## Free to play, one mana-less sacrifice to use: the Dark Sphere is the
## cheapest possible answer to one huge burn spell, and nothing else.


func build() -> CardData:
	return CardData.new("Dark Sphere", "{0}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("", true, [HalveEffect.new()],
			"{T}, Sacrifice this artifact: The next time a source of your choice would deal damage to you this turn, prevent half that damage, rounded down.") \
			.with_sacrifice_cost()) \
		.oracle("{T}, Sacrifice this artifact: The next time a source of your choice "
			+ "would deal damage to you this turn, prevent half that damage, "
			+ "rounded down.")


class HalveEffect extends EffectBase:
	func _init() -> void:
		is_damage_prevention = true   # legal in the 1997 window (§6.8)

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var candidates := _sources(game, controller)
		if candidates.is_empty():
			return
		var pick := game.agents[controller].choose_card(game, controller,
			candidates, "Choose a source for Dark Sphere")
		if pick == null or not candidates.has(pick):
			pick = candidates[0]
		game.players[controller].damage_replacements.append({
			"desc": "Dark Sphere",
			"filter": HalveEffect._from_that_source.bind(pick.id),
			"apply": HalveEffect._halve,
		})
		game.log_line("Dark Sphere braces against %s" % pick.data.card_name)

	## Every object that could deal damage to [param pid]: EVERY permanent
	## on the battlefield and everything on the stack. "A source of your
	## choice" carries no controller restriction, and your own City of
	## Brass, Mana Crypt, Electric Eel, Elves of Deep Shadow or Wormwood
	## Treefolk are all sources that deal damage to you.
	static func _sources(game: MtgGame, pid: int) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		for inst in game.all_battlefield():
			out.append(inst)
		for item in game.stack:
			if item.card != null and item.card.zone == Mtg.Zone.STACK \
					and not out.has(item.card):
				out.append(item.card)
		return out

	static func _from_that_source(_game: MtgGame, packet: DamagePacket,
			chosen_id: int) -> bool:
		return packet.source_id() == chosen_id

	static func _halve(_game: MtgGame, packet: DamagePacket) -> int:
		packet.prevent(packet.remaining() / 2)   # rounded DOWN
		return -1

	func describe() -> String:
		return "prevents half the next damage one source deals you"
