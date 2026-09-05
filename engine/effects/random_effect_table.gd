class_name RandomEffectTable
extends RefCounted
## Whimsy's grab-bag: "Play X random fast effects" — the 1997 game's list
## of seventeen, in the order of `Program/prompts.txt` `@WHIMSY_MESSAGES`
## (its eighteenth line, "made an error!", is the 1997 exe's out-of-range
## guard, not an entry). Every entry is a famous instant-speed effect
## rebuilt from mechanics the engine already has, rolled through
## [member MtgGame.rng] so a seeded duel replays a Whimsy exactly.
##
## `Duel.hlp`, Whimsy: *"If an effect requires a target, the targeting is
## also random. If there are no valid targets for a chosen fast effect,
## that fast effect fizzles."* So every entry announces itself with its
## 1997 line first ("P0 casts Crumble!") and then either acts on the object
## it rolled or logs that it fizzles — the effect happens, visibly, and the
## player learns what Whimsy tried (CR 608.2b for the rolled target being
## the only one, CR 608.2 "as much as possible" for the rest).
##
## Whose effect is it? Whimsy's caster plays every one: the token-makers
## (The Hive, Bottle of Suleiman), Sindbad and Fog act for [param
## controller] exactly as the borrowed card would for its activator, while
## an effect whose card takes "target player" rolls that player (Ancestral
## Recall, Healing Salve, Millstone, Disrupting Scepter) and one whose card
## takes a permanent rolls the permanent. Pandora's Box and Nevinyrral's
## Disk take nobody and hit everybody, as printed.
##
## Every entry follows the same contract as the rest of the engine: it acts
## only through MtgGame helpers and any question it asks (the Bottle's
## coin call, the Scepter's discard) goes through the DecisionAgent funnel.
## [Faerie Dragon] rolls on its own list: [RandomCreatureEffectTable].

## How many effects the table holds; callers roll in [0, COUNT).
const COUNT := 17

## The 1997 announcement for each entry (`@WHIMSY_MESSAGES`), logged as
## "<player> <message>" the moment the entry is played.
const MESSAGES: Array[String] = [
	"activates Time Elemental effect!",
	"casts Twiddle to untap.",
	"casts Twiddle to tap.",
	"activates Aladdin's Ring effect!",
	"casts Ancestral Recall!",
	"casts Crumble!",
	"casts Disenchant!",
	"casts Healing Salve!",
	"casts Fissure!",
	"activates Millstone effect!",
	"activates The Hive effect!",
	"activates Nevinyrral's Disk effect!",
	"activates Bottle of Suleiman effect!",
	"activates Pandora's Box effect!",
	"activates Disrupting Scepter effect!",
	"activates Fog effect!",
	"activates Sindbad effect!",
]


## Play entry [param which] of the table for [param controller], the
## player who cast Whimsy. [param source] is Whimsy itself: damage and log
## lines are attributed to it.
static func play(game: MtgGame, source: CardInstance, controller: int, which: int) -> void:
	if which < 0 or which >= COUNT:
		return
	game.log_line("%s %s" % [game.players[controller].player_name, MESSAGES[which]])
	match which:
		0:  _time_elemental(game)
		1:  _twiddle_untap(game)
		2:  _twiddle_tap(game)
		3:  _aladdins_ring(game, source)
		4:  _ancestral_recall(game)
		5:  _crumble(game)
		6:  _disenchant(game)
		7:  _healing_salve(game)
		8:  _fissure(game)
		9:  _millstone(game)
		10: _the_hive(game, controller)
		11: _nevinyrrals_disk(game, source, controller)
		12: _bottle_of_suleiman(game, source, controller)
		13: _pandoras_box(game, source, controller)
		14: _disrupting_scepter(game)
		15: _fog(game, source, controller)
		16: _sindbad(game, controller)


## Roll and play one entry.
static func play_random(game: MtgGame, source: CardInstance, controller: int) -> void:
	play(game, source, controller, RandomEffects.roll(game, COUNT))


## The `Duel.hlp` outcome for an entry that found nothing to act on.
static func _fizzle(game: MtgGame, what: String) -> void:
	game.log_line("%s fizzles (no valid target)" % what)


# ------------------------------------------------------------ the entries --
# Candidate predicates for RandomEffects.permanent. They use LIVE types
# (is_creature/is_land read cur_types), so an animated Mishra's Factory is a
# legal roll for the creature entries exactly while it is animated.

## Twiddle's untap half only makes sense on the permanent types Twiddle
## names, and only while they are tapped.
static func _is_tapped_thing(inst: CardInstance) -> bool:
	return inst.tapped and (inst.is_creature() or inst.is_land()
		or inst.is_type(Mtg.CardType.ARTIFACT))

## The mirror of [method _is_tapped_thing], for the tap half.
static func _is_untapped_thing(inst: CardInstance) -> bool:
	return not inst.tapped and (inst.is_creature() or inst.is_land()
		or inst.is_type(Mtg.CardType.ARTIFACT))

## Crumble's legal targets.
static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)

## Disenchant's legal targets.
static func _is_artifact_or_enchantment(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT) or inst.is_type(Mtg.CardType.ENCHANTMENT)

## Fissure's legal targets.
static func _is_creature_or_land(inst: CardInstance) -> bool:
	return inst.is_creature() or inst.is_land()

## Nevinyrral's Disk's blast radius.
static func _in_disk_blast(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT) or inst.is_creature() \
		or inst.is_type(Mtg.CardType.ENCHANTMENT)

## Pandora's Box looks for summon cards.
static func _is_creature_card(inst: CardInstance) -> bool:
	return inst.data.is_creature()


## Time Elemental: "Return target permanent that isn't enchanted to its
## owner's hand." Only a permanent with no Aura on it is a candidate.
static func _time_elemental(game: MtgGame) -> void:
	var target := RandomEffects.permanent(game,
		func(inst: CardInstance) -> bool:
			for aura_id in inst.attachments:
				var aura := game.find_instance(aura_id)
				if aura != null and aura.data.is_aura():
					return false
			return true)
	if target == null:
		_fizzle(game, "Time Elemental effect")
		return
	game.return_to_hand(target)


## Twiddle, untap half.
static func _twiddle_untap(game: MtgGame) -> void:
	var target := RandomEffects.permanent(game, RandomEffectTable._is_tapped_thing)
	if target == null:
		_fizzle(game, "Twiddle")
		return
	game.untap_permanent(target)


## Twiddle, tap half.
static func _twiddle_tap(game: MtgGame) -> void:
	var target := RandomEffects.permanent(game, RandomEffectTable._is_untapped_thing)
	if target == null:
		_fizzle(game, "Twiddle")
		return
	game.tap_permanent(target)


## Aladdin's Ring: 4 damage to a random creature or player.
static func _aladdins_ring(game: MtgGame, source: CardInstance) -> void:
	var target := RandomEffects.damage_target(game)
	if target == null:
		_fizzle(game, "Aladdin's Ring effect")
		return
	game.deal_damage(source, target, 4)


## Ancestral Recall: a random player draws three.
static func _ancestral_recall(game: MtgGame) -> void:
	var who := RandomEffects.player(game)
	if who < 0:
		_fizzle(game, "Ancestral Recall")
		return
	game.draw_cards(who, 3)


## Crumble: destroy a random artifact, no regeneration; its controller
## gains life equal to its mana value.
static func _crumble(game: MtgGame) -> void:
	var target := RandomEffects.permanent(game, RandomEffectTable._is_artifact)
	if target == null:
		_fizzle(game, "Crumble")
		return
	var owner: int = target.controller_id
	var mv: int = target.data.cost.mana_value()
	game.destroy(target, false)
	game.adjust_life(owner, mv)


## Disenchant: destroy a random artifact or enchantment.
static func _disenchant(game: MtgGame) -> void:
	var target := RandomEffects.permanent(game,
		RandomEffectTable._is_artifact_or_enchantment)
	if target == null:
		_fizzle(game, "Disenchant")
		return
	game.destroy(target)


## Healing Salve: a random player gains three life. (Whimsy is a sorcery:
## no damage is ever waiting to be prevented when it resolves, so the
## Salve's other mode never comes up.)
static func _healing_salve(game: MtgGame) -> void:
	var who := RandomEffects.player(game)
	if who < 0:
		_fizzle(game, "Healing Salve")
		return
	game.adjust_life(who, 3)


## Fissure: destroy a random creature or land, no regeneration.
static func _fissure(game: MtgGame) -> void:
	var target := RandomEffects.permanent(game, RandomEffectTable._is_creature_or_land)
	if target == null:
		_fizzle(game, "Fissure")
		return
	game.destroy(target, false)


## Millstone: a random player mills two.
static func _millstone(game: MtgGame) -> void:
	var who := RandomEffects.player(game)
	if who < 0:
		_fizzle(game, "Millstone effect")
		return
	game.mill(who, 2)


## The Hive: the caster gets a 1/1 flying Wasp artifact creature token.
static func _the_hive(game: MtgGame, controller: int) -> void:
	var wasp := CardData.new("Wasp", "", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["insect"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.oracle("Flying")
	game.create_token(controller, wasp)


## Nevinyrral's Disk: destroy all artifacts, creatures and enchantments.
static func _nevinyrrals_disk(game: MtgGame, source: CardInstance, controller: int) -> void:
	DestroyAllEffect.new("all artifacts, creatures, and enchantments",
		RandomEffectTable._in_disk_blast).resolve(game, source, controller, null)


## Bottle of Suleiman: the caster calls the flip (`@WHIMSY_BOTTLESULEIMAN`
## — "Call the coin flip: Heads. Tails."); winning it makes a 5/5 flying
## Djinn, losing it deals 5 damage to the caster.
static func _bottle_of_suleiman(game: MtgGame, source: CardInstance, controller: int) -> void:
	var options: Array[String] = ["Heads.", "Tails."]
	var call: int = game.agents[controller].choose_option(game, controller,
		options, "Call the coin flip:", 0)
	var landed: int = RandomEffects.roll(game, 2)
	var won: bool = call == landed
	game.log_line("%s calls %s — the coin lands %s: %s" % [
		game.players[controller].player_name, options[call].trim_suffix("."),
		options[landed].trim_suffix("."), "wins the flip" if won else "loses the flip"])
	if won:
		var djinn := CardData.new("Djinn", "", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
			.pt(5, 5) \
			.with_subtypes(["djinn"]) \
			.with_keywords([Mtg.Keyword.FLYING]) \
			.oracle("Flying")
		game.create_token(controller, djinn)
	else:
		game.deal_damage(source, TargetRef.player(controller), 5)


## Pandora's Box: a random summon card from a random library; each player
## flips a coin for a token copy of it.
static func _pandoras_box(game: MtgGame, _source: CardInstance, _controller: int) -> void:
	var chosen := RandomEffects.card_in_libraries(game, RandomEffectTable._is_creature_card)
	if chosen == null:
		_fizzle(game, "Pandora's Box effect")
		return
	game.log_line("Pandora's Box chooses %s" % chosen.data.card_name)
	for p in game.players:
		if p.has_lost:
			continue
		if game.flip_coin(p.id):
			game.create_token(p.id, chosen.data)


## Disrupting Scepter: a random player discards a card of their choice.
static func _disrupting_scepter(game: MtgGame) -> void:
	var who := RandomEffects.player(game)
	if who < 0 or game.players[who].hand.is_empty():
		_fizzle(game, "Disrupting Scepter effect")
		return
	var chosen := game.agents[who].choose_discard(game, who, 1)
	game.discard_cards(who, chosen)


## Fog: no combat damage this turn.
static func _fog(game: MtgGame, source: CardInstance, controller: int) -> void:
	PreventCombatDamageEffect.new().resolve(game, source, controller, null)


## Sindbad: the caster draws a card and reveals it (`@WHIMSY_SINDBAD` —
## "Sindbad draws..."); unless it is a land, it is discarded.
static func _sindbad(game: MtgGame, controller: int) -> void:
	game.log_line("Sindbad draws...")
	var before := game.players[controller].hand.size()
	game.draw_cards(controller, 1)
	var hand := game.players[controller].hand
	if hand.size() <= before:
		return   # drew from an empty library
	var drawn: CardInstance = hand[-1]
	game.log_line("Sindbad reveals %s" % drawn.data.card_name)
	if not drawn.data.is_land():
		game.discard_cards(controller, [drawn])
