class_name StaticAbility
extends RefCounted
## A static ability contributing a continuous effect while its source is on
## the battlefield — e.g. Holy Strength's "Enchanted creature gets +1/+2",
## or Crusade's "White creatures get +1/+1".
##
## Static abilities do not resolve; they simply ARE. On every
## ContinuousEffects.recalculate() pass the engine calls [member apply] for
## each battlefield permanent's static abilities, letting it mutate the
## cur_* characteristics of whatever it affects:
## [code]func(game: MtgGame, source: CardInstance) -> void[/code]
##
## Ordering: ContinuousEffects runs statics in passes that stand in for the
## CR 613 layers — first the ones that change TYPES (layer 4, tagged with
## [method changing_types]), then the base-P/T SETTERS (layer 7a/7b,
## [method setting_base_pt]), then everything else (layer 7c and the rest).
## Within a pass, battlefield timestamp order decides. Anything a card does
## not tag lands in the last pass, which is right for the additive majority.
##
## One tag takes its static OUT of the passes: [method changing_abilities]
## (CR 613 layer 6) is applied from ContinuousEffects._layer_six, among the
## floating grants and losses and in timestamp order with them. One more
## moves it to the END of them: [method reading_pt], for a static that asks
## a question ABOUT a power rather than writing one (Meekstone).
##
## Two floating (until-end-of-turn) passes are interleaved between those
## three, and a static must expect to be on the losing side of both: the
## layer-7b base-P/T SETS (Island of Wak-Wak) run right after the setter
## pass and therefore beat a characteristic-defining static, and the layer-5
## COLOUR changes (Dwarven Song) run right after those, so the last pass of
## statics — the anthems — already sees the repainted colours.
##
## A source whose abilities were silenced (Titania's Song, a layer-6 effect
## applied in the first pass) contributes nothing in the later passes — the
## pipeline skips it, so a static never has to check whether it still exists.
##
## The remaining approximations (no full dependency analysis beyond the two
## layer-4 rounds and the layer-7 one below, CR 613.8) are documented in
## docs/ROADMAP.md.

## func(game, source) -> void; adjust cur_power/cur_toughness/cur_keywords
## of affected instances. Runs on every recalculation, always from printed
## base values — never accumulate.
var apply: Callable

## Card-English text, for UI and logs.
var text: String = ""

## Does this static SET a base power/toughness rather than modify one?
## Characteristic-defining abilities ("Nightmare's power and toughness are
## each equal to the number of Swamps you control") and animations ("each
## Swamp is a 1/1 creature") live in CR 613 sublayer 7b and must run
## BEFORE additive boosts in 7c (Crusade, Bad Moon) whatever their
## timestamps — otherwise an anthem that entered first is silently
## overwritten and the answer depends on play order. ContinuousEffects
## runs the setters in their own pass; within each pass timestamp order
## still decides. Mark such an ability with [method setting_base_pt].
var sets_base_pt: bool = false

## Fluent: mark this static as a CR 613 layer-7b base-P/T setter.
func setting_base_pt() -> StaticAbility:
	sets_base_pt = true
	return self


## Does this static change what an object IS — its card types or subtypes
## (CR 613 layer 4)? "Nonbasic lands are Mountains" (Blood Moon),
## "enchanted land is a Swamp" (Evil Presence), "all Swamps are 1/1
## creatures" (Kormus Bell), "all artifacts are creatures" (Titania's
## Song). Layer 4 precedes every P/T layer, so these run in their own
## FIRST pass: otherwise a P/T ability that counts Swamps (Nightmare) or
## animates them reads the board before the retuning happened, and the
## answer depends on which permanent entered first. An ability that both
## retypes and sets P/T (Kormus Bell) belongs here — its P/T write is
## still ahead of every 7c anthem.
var changes_types: bool = false

## Fluent: mark this static as a CR 613 layer-4 type changer.
func changing_types() -> StaticAbility:
	changes_types = true
	return self


## Does this static RETYPE lands — replace their basic land types
## ("nonbasic lands are Mountains", "enchanted land is a Swamp")? These run
## BEFORE the other layer-4 statics, because everything that animates or
## counts land types (Kormus Bell, Living Lands, Nightmare) has to see the
## retuned board: that ordering is the CR 613.8 dependency between the two,
## resolved by construction instead of by analysis.
var changes_land_types: bool = false

## Fluent: mark this static as a land RETYPER (implies [member changes_types]).
func changing_land_types() -> StaticAbility:
	changes_land_types = true
	changes_types = true
	return self


## Does this layer-4 static READ a land type to decide what it applies to?
## "All Mountains are Plains" (Conversion) does; "Nonbasic lands are
## Mountains" (Blood Moon), "enchanted land is a Swamp" (Evil Presence,
## Phantasmal Terrain, Cyclopean Tomb) do not — they read a supertype or an
## attachment and WRITE a land type.
##
## THE DEPENDENCY (CR 613.8). Applying Blood Moon changes what Conversion
## applies to, so Conversion is dependent on Blood Moon and is applied
## after it WHATEVER the two timestamps say: a Mishra's Factory under both
## is a Plains, not a Mountain. [method ContinuousEffects.recalculate]
## runs the retypers in two waves for exactly this — writers, then readers.
## The base pool has one reader, Conversion, and two waves are the whole
## analysis there. Ice Age adds two more — Glaciers (its twin) and
## Illusionary Terrain, which READS whichever basic type its controller
## chose, Plains included, the type the other two WRITE — so the readers'
## wave orders its own members by the same rule ([method
## ContinuousEffects._ordered_readers]), from the reader's own words below.
var reads_land_types: bool = false

## What this reader READS and WRITES, as basic land type names, for the
## dependency step among readers: Conversion reads "mountain" and writes
## "plains". A reader whose two types are chosen as it enters answers
## through [member land_types_edge] instead.
var land_types_read: Array[String] = []
var land_types_written: Array[String] = []
## func(source: CardInstance) -> [reads: Array[String], writes: Array[String]]
var land_types_edge: Callable = Callable()

## Fluent: mark this layer-4 static as reading a land type (CR 613.8),
## with the types it reads and writes when they are printed on the card.
func reading_land_types(reads: Array[String] = [], writes: Array[String] = []) -> StaticAbility:
	reads_land_types = true
	land_types_read = reads
	land_types_written = writes
	return self


## Fluent: a reader whose types are chosen as its source enters
## (Illusionary Terrain) — [param edge] reads them off the source.
func reading_chosen_land_types(edge: Callable) -> StaticAbility:
	reads_land_types = true
	land_types_edge = edge
	return self


## `[reads, writes]` of this reader on [param source] — its printed types,
## or the chosen ones (empty before the choice, so nothing depends on it).
func land_type_edge(source: CardInstance) -> Array:
	if land_types_edge.is_valid():
		return land_types_edge.call(source)
	return [land_types_read, land_types_written]


## Does this static READ a creature's live POWER or TOUGHNESS to decide
## what it does? Meekstone's "creatures with power 3 or greater don't
## untap" and the two "can't attack if the defending player controls an
## untapped creature with power 3 or greater" bodies (Orgg, Goblin Mutant)
## are the pool's three. A static that only WRITES a P/T — every anthem and
## every Aura — is not one of them.
##
## THE DEPENDENCY (CR 613.8), the layer-7 twin of [member
## reads_land_types]. Every P/T layer has to have settled before the
## question is asked, or the answer depends on which permanent entered
## first: in the anthem pass a Scathe Zombies under a Bad Moon that entered
## AFTER the Meekstone was a 3/3 the Meekstone never saw, and a creature a
## Giant Growth had just made huge was invisible to all three, because the
## floating pumps of layer 7c run a pass later still. A flagged static is
## therefore applied in a pass of its own, after layer 7e's switches — the
## last thing [method ContinuousEffects.recalculate] does to a power.
## Nothing in the pool reads a power to WRITE one, so that pass has no
## readers of its own and one round is the whole analysis, exactly as it is
## for the retypers.
var reads_pt: bool = false

## Fluent: mark this static as reading a live power/toughness (CR 613.8).
func reading_pt() -> StaticAbility:
	reads_pt = true
	return self


## Does this static GRANT or REMOVE one named ability — CR 613 LAYER 6?
## Flying (Flight), fear, first strike (Lance), haste (Concordant
## Crossroads), banding (Fortified Area), a landwalk (Fishliver Oil, Lord
## of Atlantis) on the granting side; "all creatures lose flying" (Gravity
## Sphere), "enchanted creature loses flying" (Earthbind) and "as though it
## didn't have defender" (Animate Wall) on the other. NOT
## [method silencing_abilities], which is "loses ALL abilities" and runs
## before every layer because what it removes cannot contribute anywhere.
##
## THE TIMESTAMP (CR 613.7), since 2026-09-11. Layer 6 applies its effects
## in the order they were created, and a static's is the moment its source
## entered the battlefield ([member CardInstance.layer_timestamp], CR
## 613.7b). A flagged static therefore runs inside
## [method ContinuousEffects._layer_six] among the floating grants and the
## floating LOSSES rather than in a statics pass, and a Flight cast after a
## Radjan Spirit has grounded the creature puts the wings back — which it
## could not do while every static ran ahead of every floating entry.
##
## The flag is the LAYER, so it names the whole ability: an ability that
## both grants a keyword and boosts P/T is two effects in two layers (CR
## 613.1) and is printed as two statics, the flagged one carrying only the
## layer-6 half (Lord of Atlantis, Goblin King, Fortified Area, Web, Kobold
## Drill Sergeant, Primal Clay). `tests/unit/
## test_static_layer_six_2026_09_11.gd` pins that every card in the pool
## whose static writes a layer-6 ability declares itself.
var changes_abilities: bool = false

## Fluent: mark this static as a CR 613 layer-6 ability grant or removal.
func changing_abilities() -> StaticAbility:
	changes_abilities = true
	return self


## Does this static REMOVE abilities (CR 613 layer 6 — Titania's Song's
## "each noncreature artifact loses all abilities")? Layer 6 precedes every
## P/T layer, and an ability that has been removed contributes nothing in
## ANY layer, so these run FIRST and every later pass skips a source whose
## abilities are gone.
var silences_abilities: bool = false

## Fluent: mark this static as an ability remover.
func silencing_abilities() -> StaticAbility:
	silences_abilities = true
	return self


## Mtg.EventType values of the TRIGGERED abilities this static grants to
## other permanents (Energy Flux's upkeep tax on every artifact). The
## dispatcher's early-out index is rebuilt from the printed lists when the
## battlefield changes — before the grants of that recalculation exist —
## so a granting static declares what it hands out and the index counts
## it while the source is on the battlefield.
var grants_trigger_types: Array[int] = []

## Fluent: declare the event types of the triggers this static grants.
func granting_triggers(event_types: Array) -> StaticAbility:
	for t in event_types:
		grants_trigger_types.append(int(t))
	return self


func _init(p_apply: Callable, p_text: String = "") -> void:
	apply = p_apply
	text = p_text


func _to_string() -> String:
	return text if text != "" else "static ability"
