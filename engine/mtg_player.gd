class_name MtgPlayer
extends RefCounted
## One of the two duel seats: life total, zones, mana pool, and per-turn
## bookkeeping.
##
## Like CardInstance, this is a passive container — MtgGame performs all
## rule-relevant mutations (drawing dispatches events, losing ends the game,
## etc.). The zone arrays hold CardInstance objects; battlefield permanents
## additionally live in MtgGame's shared battlefield view helpers.
##
## Shandalar note: in the adventure game a player's starting life is their
## overworld "life" stat plus mana-link bonuses; the duel engine just takes
## a number, so that mapping stays in the (future) adventure layer.

## Seat index: 0 or 1.
var id: int = 0

## Display name ("You", "Sorceress", ...). Cosmetic only.
var player_name: String = ""

var life: int = 20

## Maximum hand size at cleanup (CR 402.2). Normally 7; Cursed Rack sets
## a chosen opponent's to 4, Library of Leng removes the limit entirely.
## Rebuilt from scratch by the continuous pipeline on every
## recalculation, so the effect vanishes with its source.
var max_hand_size: int = 7

## "Players play with the top card of their libraries revealed" (Field of
## Dreams): the top card of THIS player's library is public. Rebuilt by
## the continuous pipeline from the statics on the battlefield; read
## through MtgGame.revealed_top_card, which also announces a new top.
var top_card_revealed: bool = false

## "If an effect causes you to discard a card, discard it, but you may put
## it on top of your library instead of into your graveyard" (Library of
## Leng). Honoured by MtgGame.discard_cards / discard_random /
## discard_hand for an EFFECT's discard only — never for a discard paid
## as a cost or the cleanup step's. Rebuilt from scratch by the continuous
## pipeline on every recalculation.
var discard_to_library_top: bool = false

## Damage can never take this player below this life total (Ali from
## Cairo's 1). 0 = no floor. Rebuilt from scratch by the continuous
## pipeline on every recalculation.
var min_life_from_damage: int = 0

## Instance id of a permanent that soaks up damage this player would be
## dealt by ARTIFACT sources (Martyrs of Korlis). -1 = nobody. Rebuilt
## by the continuous pipeline every recalculation.
var artifact_damage_redirect: int = -1

## How much damage ARTIFACT sources have dealt to this player this turn
## (Reverse Polarity). Cleared at cleanup.
var artifact_damage_this_turn: int = 0

## Zones. Library index 0 is the BOTTOM; draws pop from the back (top).
var library: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var battlefield: Array[CardInstance] = []
var graveyard: Array[CardInstance] = []
var exile: Array[CardInstance] = []

## The ANTE: cards this player has staked on the game. The 1997 rule (and
## Shandalar's whole economy) is that the winner takes every card in the
## ante, whoever owns it — so ownership, not this array, decides who keeps
## what while the game runs. A card sits in the array of the player who
## OWNS it; MtgGame.change_owner moves it between the two.
var ante: Array[CardInstance] = []

## PHASED-OUT permanents (CR 702.25 — Oubliette). While a permanent is in
## here it is "treated as though it doesn't exist": it is off the
## battlefield arrays, so nothing sees it, but it never left the
## battlefield, so no leave/enter triggers fire when it phases in or out.
var phased_out: Array[CardInstance] = []

## OUTSIDE THE GAME (Ring of Ma'rûf). Empty in a plain duel; the adventure
## layer (M5) fills it with the player's collection, which is exactly what
## the 1997 game's Ring reaches into.
var outside_the_game: Array[CardInstance] = []

var mana_pool := ManaPool.new()

## Lands played this turn (limit 1, reset each untap step).
var lands_played_this_turn: int = 0

## MANA SUBSTITUTIONS this player may apply while paying costs
## (Sunglasses of Urza's "you may spend white mana as though it were red
## mana"), as {"from": Mtg.ManaColor, "to": Mtg.ManaColor}. Rebuilt from
## scratch by the continuous pipeline on every recalculation.
var mana_substitutions: Array[Dictionary] = []

## "For one spell this turn, you may spend mana as though it were mana of
## any type" (North Star). A counter of pending charges, consumed by the
## next cast that needs one, cleared at cleanup.
var any_color_spells: int = 0

## "You don't lose the game for having 0 or less life" (Lich). Rebuilt
## from scratch by the continuous pipeline on every recalculation.
var cant_lose_to_life: bool = false

## "If you would gain life, draw that many cards instead" (Lich) — a
## replacement effect honoured by MtgGame.adjust_life. Rebuilt by the
## continuous pipeline.
var life_gain_becomes_draw: bool = false

## How many UNTAPPED lands this player controlled as their turn began —
## snapshotted by the untap step, read by Power Surge's upkeep trigger
## ("the number of untapped lands they controlled at the beginning of this
## turn", which is not the same as the number at upkeep).
var untapped_lands_at_turn_start: int = 0

## How much damage this player has been dealt THIS TURN (Simulacrum reads
## it). Cleared at cleanup with the rest of the per-turn bookkeeping.
var damage_taken_this_turn: int = 0

## Did this player declare at least one attacker this turn? "Target player
## who attacked this turn" (Fire and Brimstone) asks about the PLAYER, and
## a creature that has since died takes its own attacked_this_turn with it.
## Cleared at cleanup.
var attacked_this_turn: bool = false

## The cards this player has DRAWN this turn, in draw order. Sylvan Library
## asks which ones ("choose two cards in your hand drawn this turn"), not
## how many, so the instances are kept rather than a count. Cleared at
## cleanup; a card that has since left the hand simply is not offered.
var drawn_this_turn: Array[CardInstance] = []

## How many draws this player has been offered in the CURRENT step, counting
## the ones a replacement effect took away. Chains of Mephistopheles' "except
## the first one they draw in each of their draw steps" is draw_number 1.
## Reset at every step boundary.
var draws_this_step: int = 0

## Instance id of a permanent that soaks up COMBAT damage this player would
## be dealt by UNBLOCKED creatures (Veteran Bodyguard). -1 = nobody;
## rebuilt by the continuous pipeline every recalculation.
var combat_damage_redirect: int = -1

## One-shot "the next time a SOURCE OF YOUR CHOICE would deal damage to
## you this turn, prevent it and gain that much life" shields (Reverse
## Damage): the instance id of each chosen source, one entry per shield.
## MtgGame.deal_damage consumes the entry naming the source. Cleared at
## cleanup.
var reverse_damage_sources: Array[int] = []

## POISON COUNTERS (CR 704.5c): ten or more and this player loses the
## game. The 1997 pool's snakes and scorpions (Marsh Viper, Pit Scorpion,
## Serpent Generator's tokens) are the only sources.
var poison: int = 0

## Set by MtgGame when a loss condition hits this player.
var has_lost: bool = false

## One-shot damage-prevention shields for THIS TURN keyed on a COLOUR.
## Each entry is an Mtg.ManaColor mask; when a source whose color
## intersects a shield would damage this player, MtgGame.deal_damage
## consumes the shield and prevents the damage. Cleared at cleanup. The
## Circles of Protection no longer use this (their printed "a red source
## OF YOUR CHOICE" names one source — a [member prevention_shield_filters]
## entry bound to its id); it stays for a colour-wide shield.
var prevention_shields: Array[int] = []

## Damage shields keyed on a SOURCE PREDICATE rather than a colour — the
## Circles of Protection (a predicate on the chosen source's id). Each entry is
## {"desc": String, "filter": Callable(source: CardInstance) -> bool,
##  "all_turn": bool}; MtgGame.deal_damage prevents the first match and
## consumes the shield UNLESS "all_turn" is set, which is Scarecrow's
## "prevent ALL damage that would be dealt to you this turn by creatures
## with flying" — one activation, every packet. Cleared at cleanup either
## way, with the colour shields.
var prevention_shield_filters: Array[Dictionary] = []

## Amount-based damage prevention for THIS TURN (Healing Salve aimed at a
## player): consumed point for point before life is lost. Cleanup clears.
var damage_prevention: int = 0

## Did this player CAST A SPELL or put a NONTOKEN PERMANENT onto the
## battlefield during their own turn? Arboria's "unless that player cast a
## spell or put a nontoken permanent onto the battlefield during their last
## turn" is the only reader. [member acted_this_turn] rolls into
## [member acted_last_turn] as that player's turn ends, so "their last turn"
## means the last turn THEY took, not the last turn anybody took.
var acted_this_turn: bool = false
var acted_last_turn: bool = false

## ONE-SHOT (or all-turn) REPLACEMENTS for damage aimed at THIS PLAYER —
## the "the next time a source of your choice would deal damage to you this
## turn, <instead>" family: Forcefield, Dark Sphere, Eye for an Eye, Nova
## Pentacle, Shimian Night Stalker. Applied by MtgGame BEFORE any
## prevention, because a replacement happens first (CR 614/616).
##
## Each entry is a Dictionary:
##   "desc"     card English, for the log;
##   "filter"   func(game: MtgGame, packet: DamagePacket) -> bool — does
##              this replacement catch that damage?
##   "apply"    func(game: MtgGame, packet: DamagePacket) -> int — what
##              happens instead. Return -1 to say "I only changed the
##              packet; carry on with what is left through the usual
##              gates", or >= 0 to finish the event there and then and
##              report that much damage dealt (0 for full prevention, N for
##              a redirect that landed N elsewhere);
##   "all_turn" true to keep the entry after it fires (Shimian Night
##              Stalker's "ALL damage ... this turn"); the default is
##              one-shot, which is what "the next time" means.
##
## Cleared at cleanup with the rest of the this-turn shields.
var damage_replacements: Array[Dictionary] = []

## "Until end of turn, if damage would be dealt to any creature, you may
## have that damage dealt to you instead" (Blood of the Martyr). A
## player-level replacement on damage aimed at CREATURES, offered per
## packet because the printed word is "may". Cleared at cleanup.
var may_take_creature_damage: bool = false

## DAMAGE CAPS: "if an instant or sorcery source would deal 3 or more
## damage to you, it deals 2 damage to you instead" (Forethought Amulet).
## Each entry is {"desc": String,
## "filter": Callable(game, source: CardInstance) -> bool,
## "threshold": int, "becomes": int}. A REPLACEMENT (CR 614), so
## MtgGame applies it before any prevention. Rebuilt by the continuous
## pipeline, like every other static-written player field.
var damage_caps: Array[Dictionary] = []

## "Until end of turn, if you tap a land you control for mana, it produces
## {U} instead of any other type" (Deep Water). An Mtg.ManaColor flag, or 0
## for no recolouring. Applied in MtgGame.tap_for_mana to LANDS only, and it
## changes the colour, never the amount. Cleared at cleanup.
var land_mana_becomes: int = 0

## "Until end of turn, any time you could activate a mana ability, you may
## pay 1 life. If you do, add {C}." (Channel.) A player-level MANA SOURCE
## rather than a permanent's ability, so it lives on the seat; the action is
## MtgGame.pay_life_for_mana. Cleared at cleanup.
var life_for_mana: bool = false

## "Until end of turn, you may pay {1} any time you could cast an instant.
## If you do, prevent the next 1 damage that would be dealt to that
## permanent or player this turn" (Guardian Angel's rider). The same shape
## as Channel: a permission on the SEAT, spent through a game action —
## MtgGame.pay_for_prevention — rather than a permanent's ability. Each
## entry is {"target": TargetRef, "desc": String}; an entry whose permanent
## has left the battlefield is dropped (CR 400.7). Cleared at cleanup.
var paid_prevention: Array[Dictionary] = []


func _init(p_id: int, p_name: String, p_life: int) -> void:
	id = p_id
	player_name = p_name
	life = p_life


## All creatures this player controls (live characteristics apply).
func creatures() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in battlefield:
		if inst.is_creature():
			out.append(inst)
	return out


func _to_string() -> String:
	return "%s(p%d, %d life)" % [player_name, id, life]
