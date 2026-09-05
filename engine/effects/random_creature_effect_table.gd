class_name RandomCreatureEffectTable
extends RefCounted
## Faerie Dragon's grab-bag: "{1}{G}{G}: Play a random effect" — the 1997
## game's list of twenty creature effects, in the order of
## `Program/prompts.txt` `@FAERIEDRAGON_MESSAGES` (with Tawnos's Wand's and
## Twiddle's lines, which the 1997 game kept in `@FAERIEDRAGON_TAWNOSWAND`
## and `@FAERIEDRAGON_TWIDDLE`, folded into their slots). Every entry is a
## famous creature spell or ability rebuilt from mechanics the engine
## already has, and every one of them acts on ONE creature — the random
## target creature the Dragon's ability rolled when it was activated
## (see [method TargetSpec.at_random]).
##
## Source: the decompiled 1997 routine at 0x4735C0 (`src/cards/promo.c`,
## `card_faerie_dragon`): on activation it rolls the effect, then rolls one
## creature among all of them (`0x473370`) as the ability's target; on
## resolution it cancels when that target is no longer a legal creature,
## else shows the 1997 message and plays the entry. Tawnos's Wand (1) on a
## creature of power 3 or more shows its own "fizzles attempting" line and
## does nothing; Twiddle (13) asks the Dragon's controller whether to tap
## or untap.
##
## The only difference from the exe: the effect INDEX is rolled here, on
## resolution, rather than at activation. The exe hid its roll until the
## ability resolved (`instance->info_slot`, never shown), so nothing a
## player could see or respond to moves — and rolling on resolution keeps
## the engine's rule that an ability on the stack carries only its targets
## and its X.
##
## Every entry follows the same contract as the rest of the engine: it acts
## only through MtgGame helpers, and Twiddle's question goes through the
## DecisionAgent funnel. [Whimsy] rolls on its own list: [RandomEffectTable].

## How many effects the table holds; callers roll in [0, COUNT).
const COUNT := 20

## The 1997 announcement for each entry, logged as "<player> <message>"
## the moment the entry is played.
const MESSAGES: Array[String] = [
	"casts Berserk!",
	"activates Tawnos's Wand effect!",
	"casts Bloodlust!",
	"casts Lifelace!",
	"casts Purelace!",
	"casts Chaoslace!",
	"casts Lightning Bolt!",
	"casts Jump!",
	"casts Giant Growth!",
	"activates Helm of Chatzuk effect!",
	"casts Deathlace!",
	"casts Thoughtlace!",
	"activates Hurr Jackal effect!",
	"casts Twiddle!",
	"activates Pradesh Gypsies effect!",
	"casts Unsummon!",
	"activates Rod Of Ruin effect!",
	"activates Sorceress Queen effect!",
	"casts Swords To Plowshares!",
	"casts Orcish Catapult!",
]

## `@FAERIEDRAGON_TAWNOSWAND`, second line.
const TAWNOS_FIZZLE := "fizzles attempting Tawnos's Wand effect!"


## Play entry [param which] of the table on [param target], a creature on
## the battlefield, for [param controller] (the Dragon's controller).
## [param source] is the Dragon: damage and log lines are attributed to it.
## A [param target] that is not a creature on the battlefield is left
## alone — the caller (the Dragon's effect) has already checked legality,
## and the exe cancelled in that case.
static func play(game: MtgGame, source: CardInstance, controller: int, which: int,
		target: CardInstance) -> void:
	if which < 0 or which >= COUNT:
		return
	if target == null or target.zone != Mtg.Zone.BATTLEFIELD or not target.is_creature():
		return
	var who: String = game.players[controller].player_name
	if which == 1 and target.cur_power >= 3:
		game.log_line("%s %s" % [who, TAWNOS_FIZZLE])
		return
	game.log_line("%s %s" % [who, MESSAGES[which]])
	match which:
		0:  _berserk(game, source, target)
		1:  _tawnos_wand(game, target)
		2:  _bloodlust(game, target)
		3:  game.set_color(target, Mtg.ManaColor.G)
		4:  game.set_color(target, Mtg.ManaColor.W)
		5:  game.set_color(target, Mtg.ManaColor.R)
		6:  game.deal_damage(source, TargetRef.card(target), 3)
		7:  _grant(game, target, Mtg.Keyword.FLYING)
		8:  _pump(game, target, 3, 3)
		9:  _grant(game, target, Mtg.Keyword.BANDING)
		10: game.set_color(target, Mtg.ManaColor.B)
		11: game.set_color(target, Mtg.ManaColor.U)
		12: _hurr_jackal(game, target)
		13: _twiddle(game, controller, target)
		14: _pump(game, target, -2, 0)
		15: game.return_to_hand(target)
		16: game.deal_damage(source, TargetRef.card(target), 1)
		17: _sorceress_queen(game, target)
		18: _swords_to_plowshares(game, target)
		19: game.add_counters(target, "-0/-1", 1)


## Roll and play one entry on [param target].
static func play_random(game: MtgGame, source: CardInstance, controller: int,
		target: CardInstance) -> void:
	play(game, source, controller, RandomEffects.roll(game, COUNT), target)


# ------------------------------------------------------------ the entries --

## +P/+T until end of turn.
static func _pump(game: MtgGame, target: CardInstance, power: int, toughness: int) -> void:
	game.continuous.add_until_eot_pump(target.id, power, toughness)
	game.recalculate()


## A keyword until end of turn.
static func _grant(game: MtgGame, target: CardInstance, keyword: int) -> void:
	game.continuous.add_until_eot_keywords(target.id, [keyword])
	game.recalculate()


## Berserk: trample and +X/+0 where X is its power; destroyed at the next
## end step if it attacked this turn.
static func _berserk(game: MtgGame, source: CardInstance, target: CardInstance) -> void:
	game.continuous.add_until_eot_pump(target.id, target.cur_power, 0,
		[Mtg.Keyword.TRAMPLE])
	game.recalculate()
	game.log_line("%s berserks %s (now %d/%d)" % [
		source.data.card_name, target.data.card_name, target.cur_power, target.cur_toughness])
	game.doom_at_next_end_step(target, true)


## Tawnos's Wand: a creature of power 2 or less can't be blocked this turn
## (the power check happened in [method play]).
static func _tawnos_wand(game: MtgGame, target: CardInstance) -> void:
	_grant(game, target, Mtg.Keyword.UNBLOCKABLE)


## Blood Lust: +4/-4, or +4/-(toughness − 1) when its toughness is below 5.
static func _bloodlust(game: MtgGame, target: CardInstance) -> void:
	var minus: int = mini(4, target.cur_toughness - 1)
	_pump(game, target, 4, -minus)


## Hurr Jackal: it can't be regenerated this turn.
static func _hurr_jackal(game: MtgGame, target: CardInstance) -> void:
	target.regeneration_banned_this_turn = true
	game.log_line("%s can't be regenerated this turn" % target.data.card_name)


## Twiddle: the Dragon's controller chooses tap or untap
## (`@FAERIEDRAGON_TWIDDLE` — "Tap." / "Untap."). The hint is the obvious
## play: untap your own creature, tap theirs.
static func _twiddle(game: MtgGame, controller: int, target: CardInstance) -> void:
	var options: Array[String] = ["Tap.", "Untap."]
	var hint: int = 1 if target.controller_id == controller else 0
	var picked: int = game.agents[controller].choose_option(game, controller,
		options, "Twiddle %s:" % target.data.card_name, hint)
	if picked == 1:
		game.untap_permanent(target)
	else:
		game.tap_permanent(target)


## Sorceress Queen: base power and toughness 0/2 until end of turn.
static func _sorceress_queen(game: MtgGame, target: CardInstance) -> void:
	game.continuous.add_until_eot_base_pt(target.id, 0, 2)
	game.recalculate()


## Swords to Plowshares: exiled; its controller gains its power in life.
static func _swords_to_plowshares(game: MtgGame, target: CardInstance) -> void:
	var life_gain := target.cur_power
	var owner := target.controller_id
	game.exile_permanent(target)
	if life_gain > 0:
		game.adjust_life(owner, life_gain)
