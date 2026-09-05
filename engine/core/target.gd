class_name TargetSpec
extends RefCounted
## Declares WHAT a spell or ability may target ("target creature", "any
## target", "target player"...), and validates candidate targets.
##
## A spell's effects each carry at most one TargetSpec, but one spec may
## demand SEVERAL targets: [TargetPlan] groups the caster's flat list of
## refs per targeting effect and validates the count, the no-duplicate rule
## (CR 601.2c) and the division arithmetic (601.2d), which is how "two
## target creatures" (Ashes to Ashes) and divided damage (Fireball,
## Pyrotechnics) work. The chosen target itself travels as a [TargetRef] —
## a small value object naming either a player or a card instance — so
## stack items never hold stale object references.
##
## Filters: [member filter] is an optional Callable
## [code]func(inst: CardInstance) -> bool[/code] narrowing legality (e.g.
## Terror's "nonartifact, nonblack"). [member description] must always state
## the requirement in card English — it is what the UI shows the player and
## what error messages quote, so keep it exact.

enum Kind {
	ANY,        ## "any target": a creature or a player
	CREATURE,   ## a creature on the battlefield
	PLAYER,     ## a player
	PERMANENT,  ## any permanent on the battlefield
	SPELL,      ## a spell on the stack (Counterspell)
	SPELL_OR_PERMANENT,  ## either — the Laces ("target spell or permanent
	                     ## becomes blue"). Legal on the stack AND on the
	                     ## battlefield, which is why it is its own kind.
	CREATURE_IN_YOUR_GRAVEYARD,  ## a creature card in the caster's
	                             ## graveyard (Raise Dead). "Your" is baked
	                             ## in because every graveyard-reaching card
	                             ## in the 1997 pool says "your graveyard".
	CARD_IN_YOUR_GRAVEYARD,      ## any card in the caster's graveyard
	                             ## (Regrowth).
	CREATURE_IN_ANY_GRAVEYARD,   ## a creature card in either graveyard
	                             ## (Animate Dead reanimates anyone's dead).
	CARD_IN_ANY_GRAVEYARD,       ## any card in either graveyard (Grave
	                             ## Robbers' artifact heist — pair with a
	                             ## filter).
	CARD_IN_ANTE,                ## any card in the shared ante zone
	                             ## (Darkpact). The ante is public, so
	                             ## either player's stake is a legal target.
	DAMAGE,                      ## one DAMAGE PACKET waiting in the 1997
	                             ## damage-prevention window (§6.8). The
	                             ## Circle of Protection ruling names the
	                             ## unit: "it targets PACKETS of the
	                             ## appropriate damage"; `Duel.hlp` calls
	                             ## the thing you click "a damage marker".
	                             ## Never legal outside a window — with the
	                             ## fork off `MtgGame.damage_pending` is
	                             ## always empty, so this kind simply has
	                             ## no candidates and a spec that carries
	                             ## it takes no target at all.
	ABILITY,                     ## one ACTIVATED ABILITY on the stack
	                             ## ("counter target activated ability from
	                             ## an artifact source" — Rust, Ayesha
	                             ## Tanaka). An ability is not a card, so
	                             ## the ref names the [StackItem]; a MANA
	                             ## ability never reaches the stack at all
	                             ## (CR 605.3a) and so is never a candidate,
	                             ## which is exactly what the printed
	                             ## "(Mana abilities can't be targeted.)"
	                             ## reminder says.
}

var kind: int = Kind.ANY

## Optional extra predicate on card instances (ignored for player targets).
var filter: Callable = Callable()

## Optional GAME-AWARE predicate [code]func(game: MtgGame,
## inst: CardInstance) -> bool[/code] for requirements that read game
## state beyond the instance itself ("target BLOCKING creature" —
## Righteousness reads combat declarations). Set via [method with_game_filter].
var game_filter: Callable = Callable()


## Fluent: attach a game-aware predicate (see [member game_filter]).
func with_game_filter(cb: Callable) -> TargetSpec:
	game_filter = cb
	return self

## Optional SOURCE-aware predicate [code]func(game: MtgGame,
## source: CardInstance, inst: CardInstance) -> bool[/code] for
## requirements stated relative to the TARGETING object's controller
## ("… that targets a permanent you control" — Avoid Fate). Set via
## [method with_source_filter]. Skipped when there is no source.
var source_filter: Callable = Callable()

## Fluent: attach a source-aware predicate (see [member source_filter]).
func with_source_filter(cb: Callable) -> TargetSpec:
	source_filter = cb
	return self

## Optional predicate on a DAMAGE PACKET [code]func(game: MtgGame,
## packet: DamagePacket, source: CardInstance) -> bool[/code] — the Circles
## of Protection's "damage from a green source" (§6.8). [member filter]
## cannot serve: it takes a CardInstance, and a packet is not one. Set via
## [method with_damage_filter].
##
## It takes the SOURCE as well as the packet, and that third argument is
## load-bearing rather than decorative: every Circle reads *"would deal
## damage TO YOU"*, and "you" is the activating player, which a predicate
## built once per [CardData] and shared by every copy cannot know any other
## way. Without it a Circle of Protection: Red could name a red packet
## aimed at anything at all (found 2026-09-01, building the AI's window
## heuristic — an AI that would otherwise have used its Circle to save a
## creature the card never mentions). [param source] may be null when a
## spec is asked in the abstract; a predicate must tolerate that.
var damage_filter: Callable = Callable()

## Fluent: attach a packet predicate (see [member damage_filter]).
func with_damage_filter(cb: Callable) -> TargetSpec:
	damage_filter = cb
	return self

## Optional predicate on a PLAYER target
## [code]func(game: MtgGame, pid: int) -> bool[/code] — "target player who
## attacked this turn" (Fire and Brimstone). [member filter] cannot serve:
## it takes a CardInstance.
var player_filter: Callable = Callable()

## Fluent: attach a player predicate (see [member player_filter]).
func with_player_filter(cb: Callable) -> TargetSpec:
	player_filter = cb
	return self

## Optional predicate on an ABILITY on the stack
## [code]func(item: StackItem) -> bool[/code] — Rust's "from an artifact
## source". [member filter] cannot serve: it takes a CardInstance, and a
## StackItem is not one.
var ability_filter: Callable = Callable()

## Fluent: attach an ability predicate (see [member ability_filter]).
func with_ability_filter(cb: Callable) -> TargetSpec:
	ability_filter = cb
	return self

## "target OPPONENT" — only a player other than the source's controller
## qualifies (Jovial Evil). Set via [method opponent]; meaningless for
## non-player kinds.
var opponent_only: bool = false

## Card-English statement of the requirement ("target nonblack creature").
var description: String = "any target"

## Does this spec ONLY ever accept Walls? Wall of Shadows says "can't be the
## target of spells that can target only Walls or of abilities that can
## target only Walls" — a statement about the SPEC, not about the source —
## so the Glyph cycle (and Animate Wall, and Ali Baba) marks itself with
## [method only_walls] and [method is_legal] honours the ban.
var wall_only: bool = false

## Fluent: mark this spec as one that can only ever target Walls.
func only_walls() -> TargetSpec:
	wall_only = true
	return self


## "… OF AN OPPONENT'S CHOICE" — the target is chosen by an opponent of the
## activating player rather than by the activator (Arena, Preacher, Nova
## Pentacle, Cuombajj Witches). It is a TARGET in every other respect (CR
## 115.1): the ability can't be activated without a legal one, shroud and
## protection keep a creature out of the list, and the ability fizzles if
## what was chosen has left by resolution. It is chosen as the ability is
## activated, together with the activator's own targets (CR 601.2c) — the
## engine asks the opponent then, through the same hold that asks a human
## which body a sacrifice cost eats ([method MtgGame._fill_adverse_targets]),
## so the activator supplies NO ref for this spec: [method TargetPlan._build]
## gives it an empty group that the ask fills.
var chosen_by_opponent: bool = false

## Optional ORDER for the chooser's candidates, from THEIR point of view:
## [code]func(game: MtgGame, source: CardInstance, a: TargetRef,
## b: TargetRef) -> bool[/code], true when [param a] should be offered
## before [param b]. The first candidate is what the chooser's heuristic
## takes (a Preacher's victim hands over the creature they would miss
## least; an Arena's opponent sends in the body most likely to win), so
## the order IS the AI's answer. Unset = the battlefield's own order.
var chooser_order: Callable = Callable()

## The prompt the CHOOSER sees — the original's own line where one exists
## (`@ARENA` "Select target creature.", `@CUOMBAJJ_WITCHES` "Select target
## creature or player."); "" builds "Select <description>."
var chooser_prompt: String = ""

## Fluent: mark this spec as one an opponent chooses (see
## [member chosen_by_opponent]), with an optional candidate [param order]
## and the [param prompt] that player is shown.
func opponent_chooses(order: Callable = Callable(),
		prompt: String = "") -> TargetSpec:
	chosen_by_opponent = true
	chooser_order = order
	chooser_prompt = prompt
	return self


## "… RANDOM TARGET creature(s)" — the Astral set's own vocabulary (Faerie
## Dragon, Goblin Polka Band, Orcish Catapult): a target NOBODY picks. The
## GAME rolls it, on [member MtgGame.rng], as the spell or ability is put
## on the stack, together with the caster's own targets (CR 601.2c says
## WHEN targets are chosen, not who chooses them), so it is a target in
## every other respect (CR 115.1): the spell can't be cast with no legal
## candidate, shroud and protection keep a creature out of the roll, what
## was rolled is on the stack item for both players to see and respond
## to, and it fizzles if it has left by resolution (CR 608.2b). The
## caster supplies NO ref for this spec — [method TargetPlan._build]
## gives it an empty group that [method MtgGame._fill_random_targets]
## fills after every refusal and every cost question, right before the
## item goes on the stack (so a held human seat's replay rolls once).
##
## The 1997 original rolled the Polka Band's victims on RESOLUTION
## (Manalink's note on its own rewrite: "This is done during resolution
## in the original version"); Faerie Dragon's creature was rolled at
## activation (`card_faerie_dragon`, 0x4735C0, decompiled). Oracle makes
## all of them targets, and targets are chosen on announcement.
var chosen_at_random: bool = false

## "a RANDOM NUMBER of random target creatures" (Orcish Catapult): HOW
## MANY is rolled too, uniformly over the effect's range as clamped by
## what exists — and, for a divided effect, by the total, since each
## target must get at least one (CR 601.2d). Without it a variable-count
## random spec takes as many as its range allows.
var random_count: bool = false

## Fluent: mark this spec as one the game rolls (see
## [member chosen_at_random]); [param count_too] rolls how many as well
## (see [member random_count]).
func at_random(count_too := false) -> TargetSpec:
	chosen_at_random = true
	random_count = count_too
	return self


## Does the CASTER name this target? False for the two kinds the engine
## fills on their behalf — an opponent's choice and a random roll — which
## is what a UI's slot builder and an AI's target picker should skip.
func is_supplied_by_caster() -> bool:
	return not chosen_by_opponent and not chosen_at_random


## A requirement stated RELATIVE TO ANOTHER TARGET of the same spell or
## ability — "target permanent an opponent controls that shares one of
## those types WITH IT" (Gauntlets of Chaos), "target creature that TARGET
## WALL blocked this turn" (Glyph of Delusion), "target artifact cards from
## TARGET PLAYER's graveyard" (Drafna's Restoration). Every other predicate
## on this class judges one candidate on its own; this one is handed the
## refs already chosen for the EARLIER slots as well:
## [code]func(game: MtgGame, source: CardInstance, candidate: TargetRef,
## earlier: Array) -> bool[/code], where [param earlier] is the flat list of
## the refs chosen for the slots before this one, in slot order. The
## candidate comes as a [TargetRef] rather than an instance because a
## sibling-bound slot may in principle want a player.
##
## It is consulted ONLY when at least one earlier ref is known. A check
## that does not know the siblings — a per-click "may I aim here?" — sees
## the candidate as provisionally legal, and the plan's validation
## ([method TargetPlan._validate]), which knows every slot, makes the
## final call and refuses the whole choice with the [member sibling_reason]
## word. The same check is repeated on resolution with the refs the stack
## item holds (CR 608.2b — a partner that stopped sharing a type is an
## illegal target).
var sibling_filter: Callable = Callable()

## The [constant WHY] word a [member sibling_filter] refusal reports —
## `type` for Gauntlets' "shares one of those types", `blocked` for the
## Glyph's Wall, `owner` for Drafna's graveyard.
var sibling_reason: String = "type"

## Fluent: attach a cross-target predicate (see [member sibling_filter])
## refusing with [param reason] (one of [constant WHY]'s words).
func with_sibling_filter(cb: Callable, reason: String = "type") -> TargetSpec:
	sibling_filter = cb
	sibling_reason = reason
	return self


func _init(p_kind: int = Kind.ANY, p_description: String = "", p_filter: Callable = Callable()) -> void:
	kind = p_kind
	filter = p_filter
	if p_description != "":
		description = p_description
	else:
		description = {
			Kind.ANY: "any target", Kind.CREATURE: "target creature",
			Kind.PLAYER: "target player", Kind.PERMANENT: "target permanent",
			Kind.SPELL: "target spell",
			Kind.SPELL_OR_PERMANENT: "target spell or permanent",
			Kind.CREATURE_IN_YOUR_GRAVEYARD: "target creature card in your graveyard",
			Kind.CARD_IN_YOUR_GRAVEYARD: "target card in your graveyard",
			Kind.CREATURE_IN_ANY_GRAVEYARD: "target creature card in a graveyard",
			Kind.CARD_IN_ANY_GRAVEYARD: "target card in a graveyard",
			Kind.CARD_IN_ANTE: "target card in the ante",
			Kind.DAMAGE: "target damage",
			Kind.ABILITY: "target activated ability",
		}[p_kind]


# --------------------------------------------------------- factory helpers --

## "Any target" — a creature or a player (Lightning Bolt).
static func any_target() -> TargetSpec:
	return TargetSpec.new(Kind.ANY)

## "Target creature", optionally narrowed by [param p_filter] (Terror's
## nonartifact, nonblack). [param desc] must read as printed card English.
static func creature(desc: String = "", p_filter: Callable = Callable()) -> TargetSpec:
	return TargetSpec.new(Kind.CREATURE, desc, p_filter)

## "Target player" — either seat (Ancestral Recall).
static func player() -> TargetSpec:
	return TargetSpec.new(Kind.PLAYER)

## "target opponent" — a player who isn't the source's controller.
static func opponent() -> TargetSpec:
	var spec := TargetSpec.new(Kind.PLAYER, "target opponent")
	spec.opponent_only = true
	return spec

## "Target spell" on the stack (Counterspell), optionally filtered.
static func spell(desc: String = "", p_filter: Callable = Callable()) -> TargetSpec:
	return TargetSpec.new(Kind.SPELL, desc, p_filter)

## "target spell or permanent" — the Laces.
static func spell_or_permanent(desc: String = "",
		p_filter: Callable = Callable()) -> TargetSpec:
	return TargetSpec.new(Kind.SPELL_OR_PERMANENT, desc, p_filter)


## "Target activated ability" on the stack, optionally filtered
## ([code]func(item: StackItem) -> bool[/code] — Rust's "from an artifact
## source"). [param desc] must read as printed card English.
static func activated_ability(desc: String = "",
		p_filter: Callable = Callable()) -> TargetSpec:
	var spec := TargetSpec.new(Kind.ABILITY, desc)
	spec.ability_filter = p_filter
	return spec


## "Target damage" — one packet waiting in the damage-prevention window
## (§6.8). [param desc] must read as the original's own prompt where there
## is one (`@CIRCLE_OF_PROTECTION` = `Select damage card.`).
static func damage(desc: String = "", p_filter: Callable = Callable()) -> TargetSpec:
	var spec := TargetSpec.new(Kind.DAMAGE, desc)
	spec.damage_filter = p_filter
	return spec


## Every object that is a legal target for this spec right now, as TargetRefs.
## Used by TargetPlan for the "choose as many as possible" clause of
## variable-count targeting (CR 601.2c) and by the AI's target picker.
## [param earlier] is the refs already chosen for the slots before this
## one, for a [member sibling_filter] to read (empty = unknown).
func legal_targets(game: MtgGame, source: CardInstance,
		earlier: Array = []) -> Array[TargetRef]:
	var out: Array[TargetRef] = []
	if kind == Kind.PLAYER or kind == Kind.ANY:
		for i in game.players.size():
			var ref := TargetRef.player(i)
			if is_legal(game, ref, source, earlier):
				out.append(ref)
	if kind == Kind.ABILITY:
		for item in game.stack:
			if item.kind != Mtg.StackKind.ABILITY:
				continue
			var ability_ref := TargetRef.ability(item)
			if is_legal(game, ability_ref, source):
				out.append(ability_ref)
		return out
	if kind == Kind.DAMAGE:
		# The window's queue IS the candidate list, and it is empty except
		# while a damage-prevention step is open.
		for packet in game.damage_pending:
			var packet_ref := TargetRef.damage(packet)
			if is_legal(game, packet_ref, source):
				out.append(packet_ref)
		return out
	var pool: Array[CardInstance] = []
	match kind:
		Kind.SPELL:
			for item in game.stack:
				if item.card != null and item.card.zone == Mtg.Zone.STACK:
					pool.append(item.card)
		Kind.SPELL_OR_PERMANENT:
			for item in game.stack:
				if item.card != null and item.card.zone == Mtg.Zone.STACK:
					pool.append(item.card)
			pool.append_array(game.all_battlefield())
		Kind.CREATURE_IN_YOUR_GRAVEYARD, Kind.CARD_IN_YOUR_GRAVEYARD, \
		Kind.CREATURE_IN_ANY_GRAVEYARD, Kind.CARD_IN_ANY_GRAVEYARD:
			for p in game.players:
				for inst in p.graveyard:
					pool.append(inst)
		Kind.CARD_IN_ANTE:
			pool.append_array(game.all_ante())
		Kind.PLAYER:
			pass
		_:
			pool = game.all_battlefield()
	for inst in pool:
		var ref := TargetRef.card(inst)
		if is_legal(game, ref, source, earlier):
			out.append(ref)
	return out


## Could this spec's requirement be satisfied by [param host] as an
## ATTACHMENT (CR 704.5m — "an Aura attached to an illegal object")? This is
## deliberately NOT [method is_legal]: attachment legality asks only what
## the object IS (its kind, the spec's filters), never whether it could be
## TARGETED. A creature with shroud that is already enchanted keeps its
## Aura — Spectral Cloak grants its own host shroud — and protection is
## handled by its own state-based action, which knows the Wards' exemption.
func can_attach_to(game: MtgGame, host: CardInstance) -> bool:
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD or host.phased_out:
		return false
	match kind:
		Kind.ANY, Kind.CREATURE:
			if not host.is_creature():
				return false
		Kind.PLAYER, Kind.SPELL:
			return false
	if filter.is_valid() and not filter.call(host):
		return false
	if game_filter.is_valid() and not game_filter.call(game, host):
		return false
	return true


# ------------------------------------------- WHY a target is illegal (§6.10) --
#
# `@PROMPT_ILLEGALTARGET` (`shandalar-src/Program/UIStrings.txt:1145`) is
# `Illegal target.` and `Illegal target (%s).`, and `:1150`
# `@PROMPT_ILLEGALTARGETWHY` supplies the 29 words that go in the brackets.
# [constant WHY] is that table, verbatim and in the table's own order,
# with the leading comma the original stores each string with dropped —
# the comma is a SEPARATOR, and the original strips it before printing
# (`shandalar-src/src/functions/targets.c:686`).
#
# **THE ITEM SAID THESE CONCATENATE. THEY DO NOT.** `docs/duel-todo.md`
# §6.10 read the accumulate-into-one-buffer shape of Manalink's
# `validate_target_impl` and concluded the player reads
# `Illegal target (type,color,tapped).` — every reason at once. Both of
# that function's failure macros end in `goto epilog`:
#
#     #define FAILURE(error_addr)                         \
#         do { rval = 0;                                  \
#              strcat(&error_str[0], EXE_STR(error_addr));\
#              goto epilog; } while (0)
#
# so exactly ONE reason is ever appended, and the epilog's
# `strcpy(return_error_str, &error_str[1])` is stripping that one string's
# own leading comma. The buffer supports concatenation; the control flow
# never produces it. Sixty-odd failure sites, every one of them a `goto`,
# and one of them carries the comment *"avoid repeating message"*.
#
# What the table really is, then, is a DIAGNOSTIC PRIORITY ORDER: the
# player is told the FIRST thing wrong with their choice, and the 29 are
# listed in the order the original tests them (compare `targets.c:219-668`
# with the table — `player`, `can't target this`, `where`, `controller`,
# `owner`, `type`, `abilities`, `color`, … is the order of both). So this
# returns one word, and the checks below run in the original's order.
#
# The Manalink-era `Text.res` renames `,name` to `,card type` and adds
# `,destroyed`, `,summoning sickness`, `,converted mana cost` and a few
# more written into spare exe space. The 1997 table is the one we ship.
const WHY := {
	"player": "player",                       # 1
	"cant_target": "can't target this",       # 2
	"where": "where",                         # 3
	"controller": "controller",               # 4
	"owner": "owner",                         # 5
	"type": "type",                           # 6
	"abilities": "abilities",                 # 7
	"color": "color",                         # 8
	"name": "name",                           # 9
	"subtype": "subtype",                     # 10
	"power": "power",                         # 11
	"toughness": "toughness",                 # 12
	"walls": "walls",                         # 13
	"spell": "spell",                         # 14
	"basic_land": "basic land",               # 15
	"artifact_creature": "artifact creature", # 16
	"target_player": "target player",         # 17
	"tapped": "tapped",                       # 18
	"attacking": "attacking",                 # 19
	"attacked": "attacked",                   # 20
	"blocked": "blocked",                     # 21
	"blocking": "blocking",                   # 22
	"attacking_blocking": "attacking/blocking",  # 23
	"enchanted": "enchanted",                 # 24
	"casted": "casted",                       # 25
	"cast_resolved": "cast resolved",         # 26
	"damaged": "damaged",                     # 27
	"can_untap": "can untap",                 # 28
	"will_untap": "will untap",               # 29
}

## Which of [constant WHY] a bespoke [member filter] / [member game_filter]
## / [member source_filter] refusal reports. Our filters are one opaque
## Callable each where the original had a dozen typed fields, so the word
## cannot be derived — it is DECLARED, and the default is the original's
## most common answer by far. Set it with [method because] on any spec
## whose filter is really asking something else ("target TAPPED creature"
## is `tapped`, not `type`).
var filter_reason: String = WHY["type"]

## Fluent: name the [constant WHY] word this spec's filter refuses with.
func because(reason: String) -> TargetSpec:
	filter_reason = reason
	return self


## Is [param ref] a legal choice for this spec in [param game] right now?
## [param source] is the card doing the targeting — needed for protection
## ("can't be the target of black spells") and to stop a spell targeting
## itself on the stack. Checked both at cast time and again at resolution
## (a spell whose targets have all become illegal fizzles, CR 608.2b).
## [param earlier] is the refs already chosen for the slots BEFORE this
## one — what a [member sibling_filter] reads; leave it empty when they
## are not known and the sibling check is deferred to the plan.
func is_legal(game: MtgGame, ref: TargetRef, source: CardInstance,
		earlier: Array = []) -> bool:
	return refusal_reason(game, ref, source, earlier) == ""


## WHY [param ref] is not a legal choice — one of [constant WHY]'s 29
## words, or `""` when it IS legal. [method is_legal] is this function
## asked for a yes or no, so the two can never drift apart: there is one
## set of checks and it is this one.
func refusal_reason(game: MtgGame, ref: TargetRef, source: CardInstance,
		earlier: Array = []) -> String:
	if ref == null:
		return WHY["cant_target"]
	# DAMAGE (§6.8). `can't target this` is the original's word for "not a
	# legal object for this at all", and it is the right one in both
	# directions: damage offered to a spell that wants a creature, and a
	# creature offered to a Circle that wants damage.
	if kind == Kind.DAMAGE or ref.is_damage:
		if kind != Kind.DAMAGE or not ref.is_damage:
			return WHY["cant_target"]
		var packet := game.find_packet(ref.packet_id)
		if packet == null:
			# The damage has landed, or was never in the window: it is not
			# THERE any more, which is what `,where` says of a card in the
			# wrong zone.
			return WHY["where"]
		if damage_filter.is_valid() \
				and not damage_filter.call(game, packet, source):
			return filter_reason
		return ""
	# ABILITY (CR 113.3b): an activated ability on the stack is an object
	# and can be targeted. A mana ability never gets there (CR 605.3a), so
	# the printed "(Mana abilities can't be targeted.)" needs no code.
	if kind == Kind.ABILITY or ref.is_ability:
		if kind != Kind.ABILITY or not ref.is_ability:
			return WHY["cant_target"]
		var item := game.find_stack_ability(ref.ability_id)
		if item == null:
			return WHY["where"]   # it has already resolved or been countered
		if ability_filter.is_valid() and not ability_filter.call(item):
			return filter_reason
		return ""
	if ref.is_player:
		# `,abilities` first, exactly as the original does it: a player
		# with shroud is refused before the question of whether this spell
		# may point at a player at all (`targets.c:219`, then `:223`).
		if ref.player_id >= 0 and ref.player_id < game.players.size() \
				and game.players[ref.player_id].has_lost:
			return WHY["player"]
		if kind != Kind.PLAYER and kind != Kind.ANY:
			return WHY["player"]
		if opponent_only and source != null and ref.player_id == source.controller_id:
			return WHY["player"]   # "target opponent" excludes its controller
		if ref.player_id < 0 or ref.player_id >= game.players.size():
			return WHY["player"]
		if player_filter.is_valid() and not player_filter.call(game, ref.player_id):
			return filter_reason
		if not _sibling_ok(game, source, ref, earlier):
			return sibling_reason
		return ""
	var inst := game.find_instance(ref.instance_id)
	if inst == null:
		return WHY["cant_target"]
	# A SPELL never targets itself (CR 114.4-adjacent: it isn't a legal
	# object for its own targets) — but an ABILITY may target its own
	# source: Samite Healer shields itself, an animated Mishra's Factory
	# pumps itself. Only block self-reference while the source sits on the
	# stack (i.e. it IS the spell being aimed).
	#
	# `can't target this` is the 1997 word: the original's own
	# `,cannot target self` is a Manalink addition written into spare exe
	# space (`targets.c:519` is a bare string literal, not an `EXE_STR`),
	# and `can't target this` — its `STATE_CANNOT_TARGET` refusal — is what
	# the 1997 table has for "not a legal object for this at all".
	if source != null and inst == source and inst.zone == Mtg.Zone.STACK:
		return WHY["cant_target"]
	if kind == Kind.SPELL:
		# A spell target lives on the stack, not the battlefield.
		if inst.zone != Mtg.Zone.STACK:
			return WHY["where"]
	elif kind == Kind.SPELL_OR_PERMANENT:
		# The Laces reach either zone. On the battlefield the usual
		# permanent protections apply (below); on the stack nothing does —
		# protection is a battlefield-object property.
		if inst.zone != Mtg.Zone.STACK and inst.zone != Mtg.Zone.BATTLEFIELD:
			return WHY["where"]
		if inst.zone == Mtg.Zone.BATTLEFIELD:
			if inst.phased_out:
				# Treated as though it doesn't exist (702.25a) — and
				# `can't target this` is the original's word for exactly
				# this state: `STATE_OUBLIETTED` is how the 1997 engine
				# spells "phased out" (`targets.c:230`).
				return WHY["cant_target"]
			if source != null and (inst.cur_protection & source.cur_colors) != 0:
				return WHY["abilities"]
			if inst.cur_shroud:
				return WHY["abilities"]
			if inst.cur_cant_be_spell_target and source != null \
					and (source.zone == Mtg.Zone.STACK
						or source.zone == Mtg.Zone.HAND):
				return WHY["abilities"]
	elif kind == Kind.CARD_IN_ANTE:
		if inst.zone != Mtg.Zone.ANTE:
			return WHY["where"]
	elif kind == Kind.CREATURE_IN_YOUR_GRAVEYARD or kind == Kind.CARD_IN_YOUR_GRAVEYARD \
			or kind == Kind.CREATURE_IN_ANY_GRAVEYARD or kind == Kind.CARD_IN_ANY_GRAVEYARD:
		if inst.zone != Mtg.Zone.GRAVEYARD:
			return WHY["where"]
		# `owner` before `type`, the order the 1997 table lists them in
		# (`,owner` is entry 5, `,type` entry 6) and the order
		# `targets.c:260` then `:268` tests them in.
		if (kind == Kind.CREATURE_IN_YOUR_GRAVEYARD
				or kind == Kind.CARD_IN_YOUR_GRAVEYARD) \
				and source != null and inst.owner_id != source.controller_id:
			return WHY["owner"]   # "your graveyard" means the ABILITY's
			                      # controller (CR 109.5) — a stolen Adun
			                      # Oakenshield digs in the THIEF's
			                      # graveyard, not in its owner's
		if (kind == Kind.CREATURE_IN_YOUR_GRAVEYARD
				or kind == Kind.CREATURE_IN_ANY_GRAVEYARD) and not inst.is_creature():
			return WHY["type"]
	else:
		if inst.zone != Mtg.Zone.BATTLEFIELD:
			return WHY["where"]
		# A phased-out permanent is treated as though it doesn't exist
		# (CR 702.25a) — nothing may target it.
		if inst.phased_out:
			return WHY["cant_target"]
		match kind:
			Kind.PLAYER:
				# A card offered where the effect must have a player:
				# `,target player` (`targets.c:473-478`).
				return WHY["target_player"]
			Kind.ANY, Kind.CREATURE:
				if not inst.is_creature():
					return WHY["type"]
			Kind.PERMANENT:
				pass
		# Protection: "can't be the Targeted by ..." (the T of DEBT, CR 702.16).
		# The original files every keyword refusal under `,abilities` — its
		# own shroud check does exactly that (`targets.c:219`) — and
		# `,color` is reserved for a spell that demands a colour of its
		# target, not for one whose colour the target is proof against.
		if source != null and (inst.cur_protection & source.cur_colors) != 0:
			return WHY["abilities"]
		# "Can't be the target of Aura spells" (Bartel Runeaxe, Tetsuo
		# Umezawa). An Aura only ever targets while it is being cast (its
		# enchant spec), so testing the source's card type is enough —
		# and it must be tested here, since cast_spell validates targets
		# while the card is still in hand.
		if inst.data.cant_be_aura_target and source != null and source.data.is_aura():
			return WHY["abilities"]
		# SHROUD: nothing may target it, not even its controller's own
		# abilities (Spectral Cloak while its host is untapped).
		if inst.cur_shroud:
			return WHY["abilities"]
		# "Can't be enchanted by other Auras" (Anti-Magic Aura) — the
		# aura that granted the ban is already attached, so any AURA
		# source still in hand or on the stack is refused.
		if inst.cur_cant_be_aura_target and source != null and source.data.is_aura() \
				and source.zone != Mtg.Zone.BATTLEFIELD:
			return WHY["enchanted"]
		# "Can't be the target of spells" (Lurker). Abilities still work: a
		# SPELL source is one being cast (still in hand while cast_spell
		# validates it) or sitting on the stack. An ability whose source has
		# since died is still an ability (CR 608.2b), which is why this asks
		# where the source IS rather than where it is not.
		if inst.cur_cant_be_spell_target and source != null \
				and (source.zone == Mtg.Zone.STACK or source.zone == Mtg.Zone.HAND):
			return WHY["spell"]
		# SOURCE-FILTERED targeting bans ("can't be the target of abilities
		# from artifact sources" — Artifact Ward).
		for ban in inst.cur_target_bans:
			if source != null and bool(ban["filter"].call(game, source, self)):
				return WHY["abilities"]
	# "Can't be the target of spells or abilities that can target only Walls"
	# (Wall of Shadows) — a property of the SPEC, wherever it points.
	if wall_only and inst.cur_immune_to_wall_only:
		return WHY["walls"]
	if filter.is_valid() and not filter.call(inst):
		return filter_reason
	if game_filter.is_valid() and not game_filter.call(game, inst):
		return filter_reason
	if source_filter.is_valid() and source != null \
			and not source_filter.call(game, source, inst):
		return filter_reason
	# Last, the requirement relative to the OTHER targets — judged only
	# when they are known (see [member sibling_filter]).
	if not _sibling_ok(game, source, ref, earlier):
		return sibling_reason
	return ""


## The [member sibling_filter] verdict, or true when it cannot be asked:
## no filter, or no earlier ref to relate the candidate to.
func _sibling_ok(game: MtgGame, source: CardInstance, ref: TargetRef,
		earlier: Array) -> bool:
	if not sibling_filter.is_valid() or earlier.is_empty():
		return true
	return bool(sibling_filter.call(game, source, ref, earlier))
