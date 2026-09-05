class_name CardInstance
extends RefCounted
## One physical copy of a card inside one game: its zone, its battlefield
## state (tapped, damage, attachments...), and its CURRENT characteristics
## after continuous effects.
##
## CardInstance is deliberately a passive data object: all rules logic lives
## in MtgGame, which is the only mutator. This keeps the engine auditable —
## to know everything that can change game state, read mtg_game.gd.
##
## Current vs printed characteristics:
## [member data] holds what is printed; [member cur_power],
## [member cur_toughness] and [member cur_keywords] hold the live values
## after the continuous-effects pipeline (ContinuousEffects.recalculate)
## has applied static abilities and until-end-of-turn effects. UI and rules
## checks must ALWAYS read the cur_* fields, never data.power etc.

## True for TOKENS (Rukh Egg's bird, The Hive's wasps). A token that
## leaves the battlefield ceases to exist (CR 704.5e) — MtgGame drops it
## instead of putting it in a graveyard — and nothing may return it.
var is_token: bool = false

## Unique per-game id, assigned by MtgGame at instantiation. Stable for the
## whole game; TargetRef and the UI layer refer to instances by this id.
var id: int = -1

## The card definition this object currently uses (shared, immutable).
## For a COPY (Clone, Copy Artifact, Vesuvan Doppelganger) this points at
## the copied card's definition — everything downstream (name, P/T,
## abilities, statics) then just works, because the whole engine reads
## [member data] for printed values. [member printed_data] remembers what
## the card really is, and leaving the battlefield restores it (CR 707.2).
var data: CardData

## What is actually printed on this card. Set once at creation; only ever
## differs from [member data] while this object is a copy.
var printed_data: CardData

## True for a COPY OF A SPELL on the stack (Fork, Chain Lightning's
## rider). It is not a card: when it finishes resolving it ceases to
## exist instead of going to a graveyard (CR 707.10a / 608.2m).
var is_copy: bool = false

## Player id (0/1) who owns the card (whose deck it started in).
var owner_id: int = 0

## Player id currently controlling it. Changed by MtgGame.change_control
## (Control Magic, Old Man of the Sea's leash, Disharmony's until-EOT
## borrow) and reset to the owner when the object leaves the battlefield
## (CR 110.2).
var controller_id: int = 0

## Which Mtg.Zone the card is in right now. Only MtgGame moves cards.
## Leaving the HAND wipes the hand-scoped state below (CR 400.7: the card
## that leaves is a new object, and "that card" of a rider on its stay in
## the hand no longer exists).
var zone: int = Mtg.Zone.LIBRARY:
	set(value):
		if zone == Mtg.Zone.HAND and value != Mtg.Zone.HAND:
			hand_lock_turn = -1
			revealed_in_hand = false
		zone = value

# ------------------------------------------------------ hand-only state --

## "Until your next turn, you play with that card revealed in your hand
## and can't play it" (Firestorm Phoenix): the turn number on which the
## card was locked, or -1 when it may be played. MtgGame refuses
## cast_spell/play_land while it is set and lifts it as its owner's next
## turn begins (MtgGame._end_turn).
var hand_lock_turn: int = -1

## The card is PUBLIC while in the hand (the rider above): the duel screen
## may show it to the opponent and the AI may read it.
var revealed_in_hand: bool = false

# ------------------------------------------------ battlefield-only state --

## Tapped/untapped.
var tapped: bool = false

## Damage marked this turn (cleared at cleanup, CR 514.2).
var damage: int = 0

## True until its controller has begun a turn with it (summoning sickness,
## CR 302.6). Cleared by MtgGame during the untap step. Haste bypasses it.
var summoning_sick: bool = false

## CONTROL LEASH: the instance id of the permanent whose presence (and,
## when [member leash_needs_tapped] is set, whose tapped state) sustains
## this permanent's change of control — Old Man of the Sea, Rubinia
## Soulsinger, Aladdin, Preacher. -1 = this permanent's control isn't
## leashed. MtgGame checks the leash as a state-based action and hands
## the permanent back the moment the condition fails.
var controlled_via: int = -1
var leash_needs_tapped: bool = false

## The other half of Old Man of the Sea's leash: "...and that creature's
## power remains less than or equal to this creature's power". A CONTINUING
## condition, not a one-off check at activation, so it lives here beside
## [member leash_needs_tapped] and is tested by the same state-based
## action — Giant Growth on the stolen creature hands it straight back.
var leash_power_capped: bool = false

## For auras: the id of the permanent this is attached to (-1 = none).
var attached_to: int = -1

## Ids of auras (later: equipment) attached to this permanent.
var attachments: Array[int] = []

## Counters on this permanent, kind -> count ("+1/+1", "-1/-1", ...).
## The continuous pipeline applies any counter whose NAME parses as a P/T
## delta in CR 613 layer 7d — after the base-P/T setters (so a Nightmare's
## own ability cannot wipe them) and before the layer-7c anthems and the
## statics that READ power (Meekstone). Counters vanish when the card
## leaves the battlefield (CR 121.2).
var counters: Dictionary = {}

## Instance ids of sources that dealt damage to this creature THIS TURN
## (Sengir Vampire's bookkeeping). Cleared at cleanup; snapshotted into
## the DIES event before battlefield state wipes.
var damaged_by_this_turn: Array[int] = []

## The same ledger with AMOUNTS: source instance id -> total damage that
## source has dealt to this permanent this turn. `damaged_by_this_turn`
## answers "who bit me" (Sengir Vampire, Giant Shark); this answers "how
## much did THAT source deal to ME", which is what Blazing Effigy's
## *"3 plus the amount of damage dealt to this creature this turn by other
## sources named Blazing Effigy"* is a question about. Kept beside the list
## rather than replacing it because the two are asked separately and the
## list is the cheap one. Cleared and snapshotted with it.
var damage_from_this_turn: Dictionary = {}

## Regeneration shields built up this turn (CR 701.15): each one replaces
## the next destruction with tap + clear damage + leave combat. Created by
## RegenerateEffect, consumed by MtgGame.destroy, expired at cleanup.
var regeneration_shields: int = 0

## "This creature can't be regenerated this turn" (Hurr Jackal,
## Whippoorwill). MtgGame.destroy ignores every shield while this is set;
## cleared at cleanup with the shields themselves.
var regeneration_banned_this_turn: bool = false

## ATTACK COSTS (CR 508.1g): "can't attack unless its controller pays {3}"
## (Brainwash), "can't attack unless you sacrifice two Islands"
## (Leviathan). Each entry is a Dictionary
## {"desc": String, "can_pay": Callable(game, pid) -> bool,
##  "pay": Callable(game, pid) -> void}; MtgGame.declare_attackers checks
## every declared attacker's costs BEFORE paying any of them, so a
## declaration it has to refuse leaves nothing spent. Set by statics each
## recalculation, exactly like cur_cant_attack.
var cur_attack_costs: Array[Dictionary] = []

## "For each 1 damage that would be dealt to this creature, if it has a
## <kind> counter on it, remove one and prevent that 1 damage" (Rock
## Hydra). A REPLACEMENT, applied before every prevention gate. "" = none;
## the value is the counter kind, so the same field would serve any
## counter-eating armour. Set by a static each recalculation.
var damage_eats_counters: String = ""

## "ALL damage that would be dealt this turn by this source is dealt to
## <player> instead" (Reverberation) — a replacement on the SOURCE rather
## than on a victim, so it is applied before anything about the target.
## -1 = none. Cleared at cleanup and by a zone change.
var damage_all_redirect_to: int = -1

## DESTRUCTION SHIELDS: "the next time this permanent would be destroyed
## this turn, remove all damage marked on it instead" (Pyramids). A
## replacement effect like regeneration (CR 614/701.15) but WITHOUT
## regeneration's tap and remove-from-combat, which is why it is its own
## counter — a land the Pyramids saved is not tapped. Consumed one per
## destruction, checked before the regeneration shields; cleared at cleanup.
var destruction_shields: int = 0

## "Damage that would be dealt to that creature this turn can't be
## prevented or dealt instead to another permanent or player"
## (Whippoorwill). Read by MtgGame._land_damage_impl, which then skips
## every prevention and redirection gate — protection included, since
## CR 702.16e makes protection prevent the damage. Cleared at cleanup.
var damage_unpreventable_this_turn: bool = false

## Damage-prevention pool for THIS TURN (Healing Salve, Samite Healer):
## incoming damage consumes it point for point. Cleared at cleanup.
var prevention: int = 0

## BLOCK HISTORY: creatures this permanent BLOCKED this turn, as
## {attacker instance id: the controller it had when the block happened}.
## The whole Glyph cycle reads it ("target creature that target Wall
## blocked this turn"; "the player who controlled that creature the last
## time it became blocked by that Wall"). Cleared at cleanup with the rest
## of the per-turn bookkeeping.
var blocked_ids_this_turn: Dictionary = {}

## "It blocks each attacking creature this turn if able" (Blaze of Glory).
## While set, declare_blockers refuses a declaration that leaves this
## creature out of a block it could legally make — EACH of them, since the
## same card also sets [member extra_blocks_this_turn] to -1 and the
## engine's blocks became one-to-many on 2026-09-02. Cleared at cleanup.
var must_block_this_turn: bool = false

## PHASED OUT (CR 702.25): still on the battlefield in the rules sense,
## but "treated as though it doesn't exist" — MtgGame keeps it out of the
## battlefield arrays, so no query, static, trigger or state-based action
## sees it, and TargetSpec refuses it.
var phased_out: bool = false

## "If it would die this turn, exile it instead" (Disintegrate). A
## replacement honoured by MtgGame; cleared at cleanup.
var exile_instead_of_dying: bool = false

## "Exile <this spell>" as part of its own resolution (Recall). Set by the
## resolving effect; MtgGame sends the finished spell to exile instead of
## its owner's graveyard.
var exile_after_resolution: bool = false

## "The next time a source of your choice would deal damage to this
## creature this turn, that damage is dealt to <player> instead" (Jade
## Monolith). -1 = no redirection; [member damage_redirects] counts how
## many one-shot redirections are pending. Cleared at cleanup.
var damage_redirect_to: int = -1
var damage_redirects: int = 0
## The instance ids of the sources those redirections were bought against
## — "a source of your choice", one entry per Monolith activation. Empty
## = any source (Personal Incarnation's "the next 1 damage"). Cleared
## with the two above.
var damage_redirect_sources: Array[int] = []
## "The next 1 damage that would be dealt to this creature this turn is
## dealt to its owner instead" (Personal Incarnation) — a METERED redirect,
## one point per activation, the rest of the event still landing here.
## -1 = nobody; [member damage_point_redirects] is the pool of points.
## Cleared at cleanup and when the card leaves the battlefield.
var damage_point_redirect_to: int = -1
var damage_point_redirects: int = 0

## "This creature attacks this turn if able" (Nettling Imp, Siren's Call).
## declare_attackers refuses a declaration that leaves it at home; cleared
## at cleanup.
var must_attack_this_turn: bool = false

## FACE DOWN (Illusionary Mask): a 2/2 colourless creature with no name,
## types beyond Creature, or abilities, until it is turned face up.
var face_down: bool = false

## Whether this creature BLOCKED this turn (set in declare_blockers,
## cleared at cleanup). Lurker's "unless it attacked or blocked this
## turn" reads it alongside attacked_this_turn.
var blocked_this_turn: bool = false

## Whether this creature attacked this turn (set in declare_attackers,
## cleared at its controller's untap). Erg Raiders-style punishments and
## future AI heuristics read this.
var attacked_this_turn: bool = false

## Whether this creature COULD have been declared as an attacker this turn
## — the census MtgGame.declare_attackers takes of the active player's
## creatures as attackers are declared, whether or not any attack (CR
## 508.1a is the only moment a creature can attack, so "creatures that
## couldn't attack" — Season of the Witch — is judged there and nowhere
## else). Cleared with attacked_this_turn.
var could_attack_this_turn: bool = false

## Player ids this permanent DEALT DAMAGE to this turn (Whirling Dervish's
## "if this creature dealt damage to an opponent this turn"; Nicol Bolas
## and Merchant Ship read the same list). Filled by MtgGame.deal_damage,
## cleared at cleanup with the rest of the per-turn bookkeeping.
var damaged_players_this_turn: Array[int] = []

## Card TYPES permanently ADDED while on the battlefield (Ashnod's
## Transmogrant's "that creature becomes an artifact in addition to its
## other types"). Re-applied after every characteristics reset; cleared
## when the card leaves the battlefield.
var added_types: int = 0

## Keywords PERMANENTLY stripped while on the battlefield (Elder Land
## Wurm's "loses defender") — re-removed after every characteristics
## reset; cleared when the card leaves the battlefield.
var removed_keywords: Array[int] = []

## Keywords granted with NO DURATION — "that creature gains flying" with
## nothing after it (Cocoon's hatching), which lasts for as long as the
## creature stays on the battlefield rather than until end of turn. The
## mirror of [member removed_keywords]: re-added after every
## characteristics reset, cleared when the card leaves the battlefield.
## Until-end-of-turn grants do NOT come here — they float in
## ContinuousEffects (PumpEffect's keyword list).
var added_keywords: Array[int] = []

## Protection colours granted PERMANENTLY while on the battlefield
## (Rainbow Knights' "gains protection from a random color permanently").
## OR'd into cur_protection after every characteristics reset; cleared when
## the card leaves the battlefield.
var added_protection: int = 0

## TEXT CHANGES (CR 613 layer 3) applied to this object indefinitely —
## Magical Hack's basic land types, Sleight of Mind's colour words, Quarum
## Trench Gnomes' mana. Each entry is one of:
##   {"kind": "land_type",  "from": String, "to": String}
##   {"kind": "color_word", "from": int,    "to": int}
##   {"kind": "mana_color", "from": int,    "to": int}
## Re-applied at the END of every characteristics reset (layer 3 runs before
## types, colours, abilities and P/T), cleared when the card leaves the
## battlefield.
## SIMPLIFIED (docs/simplified-cards.md, "text changes"): a text change
## reaches subtypes, landwalk types, protection colours and a land's mana —
## not arbitrary rules text, which this engine does not store as text.
var text_changes: Array[Dictionary] = []

## INDEFINITE colour change (CR 613 layer 5) — the Laces, Alchor's Tomb,
## Aisling Leprechaun, Dream Coat. -1 = this object still has its printed
## colours; otherwise an Mtg.ManaColor bitmask (0 is legal and means
## "colourless"). A Lace aimed at a SPELL sets it while the card is on the
## stack, and the change rides along when the spell resolves into a
## permanent — exactly as printed. It ends when the object changes zones
## off the battlefield (clear_battlefield_state).
var color_override: int = -1

## An Aura that returned to the battlefield "as a non-Aura enchantment"
## and "loses 'enchant creature'" (Takklemaggot, MtgGame.
## return_aura_unattached): it sits on the battlefield attached to nothing
## and the orphaned-Aura state-based action (CR 704.5m) leaves it alone,
## because [method is_aura] is false. Wiped when it leaves the battlefield
## (CR 400.7) — the printed card is an Aura again.
var lost_enchant: bool = false

## Card-local scratch state for choices a permanent remembers while it is
## on the battlefield ("as this enters, choose a basic land type" —
## Phantasmal Terrain; "choose a colour and an opponent" — Jihad). Cards
## own the keys; the engine only clears the dictionary when the permanent
## leaves the battlefield (CR 400.7).
var memory: Dictionary = {}

## Per-turn activation counts for this permanent's activated abilities
## (ability index -> uses this turn) — Fire Drake's "only once each
## turn". Cleared every cleanup step.
var ability_uses: Dictionary = {}

## One-shot "doesn't untap during its controller's NEXT untap step"
## (Barl's Cage) — consumed and cleared by that untap step.
var skip_next_untap: bool = false

## "Doesn't untap during its controller's next N untap steps"
## (Telekinesis: two). Decremented by each of those untap steps.
var skip_untaps: int = 0

## "Can't attack during its controller's next turn" (Wall of Dust):
## the NEXT flag is raised when the ban is imposed; the controller's
## untap step shifts it into the THIS flag (checked by attack legality)
## and clears it a turn later.
var cant_attack_next_turn: bool = false
var cant_attack_this_turn: bool = false

# ------------------------------------------- current characteristics --
# Rebuilt from scratch by ContinuousEffects.recalculate() after every
# game-state change. Never write these outside that pipeline.

var cur_power: int = 0
var cur_toughness: int = 0

## LAST KNOWN INFORMATION (CR 608.2h): the live characteristics this object
## had at the moment it LEFT the battlefield. Zone changes reset cur_* to
## printed values, so anything that reads a dead or sacrificed permanent's
## characteristics — Creature Bond's "that creature's toughness", Diamond
## Valley, Life Chisel, "whenever a creature dies" counters, Necropolis of
## Azar's "non-black creature" — must read these instead of cur_* or data.
## [member last_types] is why an animated Mishra's Factory that dies counts
## as a creature dying, and [member last_colors] is why a Deathlaced bear
## does not.
var last_power: int = 0
var last_toughness: int = 0
var last_types: int = 0
var last_colors: int = 0
var last_subtypes: Array[String] = []

var cur_keywords: Array[int] = []
## Live COLOURS as an Mtg.ManaColor bitmask (CR 105.2 / 613 layer 5).
## Printed colours come from the mana cost; the Laces, Dream Coat and
## friends replace them. Rules code and card filters ask the INSTANCE
## (inst.cur_colors / inst.has_color), never data.color_mask().
var cur_colors: int = 0
## Live TYPE mask and subtypes — animation effects (Mishra's Factory)
## add to these until end of turn. Rules code asks the INSTANCE
## (is_creature()/has_subtype()), never data, for battlefield objects.
var cur_types: int = 0
var cur_subtypes: Array[String] = []
## Live ACTIVATED ABILITIES. Reset to the printed list every
## recalculation; statics may APPEND granted abilities (Zombie Master
## hands "{B}: Regenerate this permanent" to every other Zombie).
## MtgGame.activate_ability reads THIS list, never data.activated_abilities.
var cur_activated_abilities: Array[ActivatedAbility] = []

## Live TRIGGERED ABILITIES. Reset to the printed list every
## recalculation; statics may APPEND granted abilities (Energy Flux hands
## "At the beginning of your upkeep, sacrifice this artifact unless you
## pay {2}" to every artifact). MtgGame.dispatch_event reads THIS list,
## never data.triggered_abilities, so a granted trigger belongs to the
## permanent that carries it — its controller controls the trigger, and
## a silencer (Titania's Song) takes it away with the printed ones. A
## static that grants triggers declares their event types
## (StaticAbility.granting_triggers) so the dispatcher's index knows to
## look.
var cur_triggered_abilities: Array[TriggeredAbility] = []

## Live MANA ABILITIES. Reset to the printed list every recalculation;
## statics that change what a land IS (Evil Presence, Phantasmal Terrain,
## Blood Moon, Conversion) replace it wholesale, which is what makes an
## "enchanted land is a Swamp" actually tap for {B}. MtgGame.tap_for_mana
## reads THIS list, never data.mana_abilities.
var cur_mana_abilities: Array[ManaAbility] = []

## Live protection mask (CR 702.16). Rebuilt every recalculation from the
## printed value plus [member added_protection] (Rainbow Knights' permanent
## grant) plus whatever the Wards and other statics add.
var cur_protection: int = 0
## Live landwalk types — statics can grant these (Goblin King, Burrowing).
var cur_landwalk: Array[String] = []
## Live RAMPAGE N (CR 702.23). Printed on Legends' creatures, but also
## GRANTED — by a static that changes every upkeep (Gabriel Angelfire) and
## as an until-end-of-turn floating effect (Rapid Fire). Combat reads this,
## never data.rampage (CONTRIBUTING.md rule 5).
var cur_rampage: int = 0

## The three PRINTED BLOCK RESTRICTIONS, live. Juggernaut's "can't be
## blocked by Walls", Ironclaw Orcs' "can't block creatures with power 2 or
## greater", Amrou Kithkin's "can't be blocked by creatures with power 3 or
## greater". These were the last combat characteristics CombatState still
## read off `data`, which meant a permanent put onto the battlefield FACE
## DOWN — a nameless 2/2 with no abilities at all, CR 708.2 — kept
## announcing them. Rebuilt from the printed values every recalculation,
## and cleared with everything else by the face-down branch below.
var cur_cant_be_blocked_by: Array[String] = []
var cur_cant_block_power_ge: int = 0
var cur_cant_be_blocked_by_power_ge: int = 0

## HOW MANY ADDITIONAL ATTACKERS THIS CREATURE MAY BLOCK, beyond the one
## every blocker may block (CR 509.1b). 0 for almost everything; -1 means
## ANY NUMBER.
##
## Two sources, and they are different in kind, which is why there are two
## fields. This one is the PRINTED permission — Two-Headed Giant of Foriys'
## *"can block an additional creature each combat"* — rebuilt from
## [member CardData.extra_blocks] every recalculation and cleared by the
## face-down branch like every other printed combat characteristic
## (CR 708.2). [member extra_blocks_this_turn] is the granted one.
var cur_extra_blocks: int = 0

## A GRANTED "may block more" for this turn — Blaze of Glory's *"can block
## any number of creatures this turn"*, which is -1. Lives beside
## [member must_block_this_turn] (the same card sets both) and is cleared
## at cleanup with it, so it survives a recalculation the way a turn-scoped
## flag must.
var extra_blocks_this_turn: int = 0
## "Doesn't untap during its controller's untap step" — set by statics
## (Meekstone) each recalculation; the untap step honors it.
var cur_skips_untap: bool = false
## "Can't attack" — set by statics (Moat bans non-flyers) each
## recalculation; checked in CombatState.attack_illegality.
var cur_cant_attack: bool = false
## "LOSES ALL ABILITIES" (Titania's Song). The mana and activated lists
## are live and simply get cleared; TRIGGERED and STATIC abilities are
## still read off [member data], so this flag is what tells MtgGame's
## dispatcher and the continuous pipeline to skip them. Set by statics
## each recalculation.
var cur_abilities_silenced: bool = false

## 1997 RULE (manual p.124): "When an artifact is tapped, its continuous
## effects cease. This does not apply to artifact creatures." Set during
## the recalculation when RulesOptions.tapped_artifacts_stop is on, and
## checked by the static passes. SEPARATE from cur_abilities_silenced
## because the 1997 rule suspends only CONTINUOUS effects — a tapped
## artifact's activated abilities (an untap cost, a sacrifice) still work.
var cur_statics_suspended: bool = false

## "Can attack as though it had haste" (Instill Energy). Deliberately NOT
## the HASTE keyword: haste also unlocks {T} costs (CR 302.6), which this
## wording does not — an enchanted Llanowar Elves may swing the turn it
## arrives but still cannot tap for mana. Set by statics each recalculation.
var cur_attacks_as_if_hasty: bool = false
## "Can't be blocked except by …" restrictions — each entry is a
## Dictionary {"desc": String, "filter": Callable(blocker) -> bool}; a
## would-be blocker must satisfy EVERY entry (multiple restrictions
## intersect). Set by statics each recalculation (Invisibility → Walls,
## Elven Riders → Walls/flyers, Seeker → artifact/white).
var cur_block_restrictions: Array[Dictionary] = []
## "Bands with other [quality]" (CR 702.22c, second sentence) — each entry
## is a Dictionary {"desc": String, "filter": Callable(CardInstance) ->
## bool}: a band is legal when one member holds an entry and EVERY member
## passes its filter, and two blockers who both pass one of them hand the
## attacker's division to the defender (CR 702.22j). NOT banding: the
## keyword is not granted with it, and a creature with only this is the
## band's "one creature without banding" under the first form. Set by
## statics each recalculation (the Legends banding lands); losing banding
## clears it too (CR 702.22b — Tolaria).
var cur_bands_with: Array[Dictionary] = []
## "Prevent all damage that would be dealt to this creature by creatures"
## (Uncle Istvan) — set by statics; honored in MtgGame.deal_damage for
## combat damage and creature-sourced ability damage alike.
var cur_prevent_damage_from_creatures: bool = false
## "All creatures able to block this creature do so" (Lure). Set by
## statics each recalculation; MtgGame.declare_blockers refuses a
## declaration that leaves an able blocker at home.
var cur_must_be_blocked: bool = false

## Narrows [member cur_must_be_blocked] to a subset of would-be blockers
## — Marble Priest's "all WALLS able to block this creature do so".
## Unset = every able creature must block. func(blocker) -> bool.
var cur_must_be_blocked_filter: Callable = Callable()

## SHROUD: "can't be the target of spells or abilities" (Spectral Cloak).
## Set by statics each recalculation; TargetSpec refuses every source.
var cur_shroud: bool = false

## "Can't be enchanted by other Auras" (Anti-Magic Aura's second clause).
## Set by statics; TargetSpec refuses AURA sources other than the one
## granting the ban.
var cur_cant_be_aura_target: bool = false

## "Prevent all damage that would be dealt BY this creature this turn"
## (Kry Shield) — unlike cur_prevent_combat_damage_dealt this covers
## non-combat damage too.
var cur_prevent_all_damage_dealt: bool = false

## "Can't be the target of SPELLS" (Lurker while it has neither attacked
## nor blocked; the Spectral Cloak shroud). Set by statics each
## recalculation; TargetSpec refuses spell sources aimed at it, while
## abilities still work — which is exactly Lurker's printed wording.
var cur_cant_be_spell_target: bool = false

## "Prevent all COMBAT damage that would be dealt BY this creature"
## (Gaseous Form, Demonic Torment) — honored in MtgGame.deal_damage only
## for damage flagged as combat damage, so the creature's own ping
## abilities still work.
var cur_prevent_combat_damage_dealt: bool = false
## "Prevent all COMBAT damage that would be dealt TO this creature"
## (Gaseous Form) — same combat-only gate.
var cur_prevent_combat_damage_taken: bool = false
## INDESTRUCTIBLE (CR 700.4): destruction and lethal damage do nothing to
## it. Set by statics each recalculation (Consecrate Land).
var cur_indestructible: bool = false

## "Other players can't gain control of it" (Guardian Beast). Set by
## statics each recalculation and honoured by MtgGame.change_control, which
## is the one door every control change goes through — the leashes, the
## until-end-of-turn borrows and the CR 701.10 exchange included.
var cur_cant_change_control: bool = false

## "Prevent ALL damage that would be dealt to this creature this turn"
## (Glyph of Destruction) — combat and non-combat alike.
var cur_prevent_all_damage_taken: bool = false
## SOURCE-FILTERED TARGETING BANS: "can't be the target of abilities from
## artifact sources" (Artifact Ward). Each entry is a Dictionary
## {"desc": String, "filter": Callable(game, source, spec) -> bool}; if ANY
## filter accepts the targeting source, this object is not a legal target.
## Set by statics each recalculation, read by TargetSpec.is_legal.
var cur_target_bans: Array[Dictionary] = []

## "Can't be the target of spells or abilities that can TARGET ONLY WALLS"
## (Wall of Shadows). The Glyph cycle's specs declare themselves with
## TargetSpec.only_walls(); this flag is set by statics each recalculation.
var cur_immune_to_wall_only: bool = false

## SOURCE-FILTERED damage immunities: "prevent all damage that would be
## dealt to this creature by <X>". Each entry is a Dictionary
## {"desc": String, "filter": Callable(game, source) -> bool} plus an
## optional "combat": true for the "all COMBAT damage" wordings
## (Enchanted Being, Marble Priest); if ANY filter accepts the damage
## source, the damage is prevented entirely.
## Set by statics each recalculation (Wall of Vapor's "creatures it's
## blocking", Argothian Pixies' artifact creatures, Wall of Putrid
## Flesh's enchanted creatures, Desert Nomads' Deserts).
var cur_damage_immunity: Array[Dictionary] = []


func _init(p_data: CardData, p_id: int, p_owner: int) -> void:
	data = p_data
	printed_data = p_data
	id = p_id
	owner_id = p_owner
	controller_id = p_owner
	reset_characteristics()


## Restore cur_* to printed values — step one of every recalculation.
##
## PERFORMANCE: this runs for every battlefield permanent on every single
## recalculation, which makes it the engine's hottest allocation site. The
## live lists are therefore REFILLED IN PLACE (Array.assign — one call, no
## new Array per permanent per pass) rather than replaced with fresh
## duplicates. Nothing may hold on to one of these arrays expecting a
## snapshot — they are live views by contract (see the class doc).
func reset_characteristics() -> void:
	cur_statics_suspended = false
	cur_power = data.power
	cur_toughness = data.toughness
	cur_protection = data.protection_from | added_protection
	cur_types = data.types | added_types   # permanent grants (Transmogrant)
	cur_colors = data.color_mask() if color_override < 0 else color_override
	cur_keywords.assign(data.keywords)
	cur_landwalk.assign(data.landwalk)
	cur_rampage = data.rampage
	cur_cant_be_blocked_by.assign(data.cant_be_blocked_by)
	cur_cant_block_power_ge = data.cant_block_power_ge
	cur_cant_be_blocked_by_power_ge = data.cant_be_blocked_by_power_ge
	cur_extra_blocks = data.extra_blocks
	cur_subtypes.assign(data.subtypes)
	if lost_enchant:
		cur_subtypes.erase("aura")   # "as a non-Aura enchantment" (Takklemaggot)
	cur_mana_abilities.assign(data.mana_abilities)
	cur_activated_abilities.assign(data.activated_abilities)
	cur_triggered_abilities.assign(data.triggered_abilities)
	cur_block_restrictions.clear()
	cur_bands_with.clear()
	cur_damage_immunity.clear()
	cur_target_bans.clear()
	cur_immune_to_wall_only = false
	cur_skips_untap = false
	cur_cant_attack = false
	cur_attack_costs = []
	cur_attacks_as_if_hasty = false
	cur_abilities_silenced = false
	cur_prevent_damage_from_creatures = false
	cur_cant_be_spell_target = false
	cur_shroud = false
	cur_cant_be_aura_target = false
	cur_prevent_all_damage_dealt = false
	cur_must_be_blocked = false
	cur_must_be_blocked_filter = Callable()
	cur_prevent_combat_damage_dealt = false
	cur_prevent_combat_damage_taken = false
	cur_prevent_all_damage_taken = false
	cur_indestructible = false
	cur_cant_change_control = false
	damage_eats_counters = ""
	for k in added_keywords:     # durationless grants (Cocoon's flying)
		if not cur_keywords.has(k):
			cur_keywords.append(k)
	for k in removed_keywords:   # permanent losses (Elder Land Wurm)
		cur_keywords.erase(k)
	if not text_changes.is_empty():
		_apply_text_changes()
	if face_down:
		# A face-down permanent is a 2/2 colourless creature with no name,
		# no other types and NO ABILITIES at all (CR 708.2) — including the
		# triggered and static ones, which live on `data` and are therefore
		# suppressed through the same flag Titania's Song uses.
		cur_power = 2
		cur_toughness = 2
		cur_types = Mtg.CardType.CREATURE
		cur_colors = 0
		cur_subtypes.clear()
		cur_keywords.clear()
		cur_landwalk.clear()
		cur_rampage = 0
		cur_cant_be_blocked_by.clear()
		cur_cant_block_power_ge = 0
		cur_cant_be_blocked_by_power_ge = 0
		cur_extra_blocks = 0
		cur_protection = 0
		cur_mana_abilities.clear()
		cur_activated_abilities.clear()
		cur_triggered_abilities.clear()
		cur_abilities_silenced = true


## CR 613 layer 3, applied right after the printed values are restored.
func _apply_text_changes() -> void:
	for change in text_changes:
		match String(change["kind"]):
			"land_type":
				var from_type := String(change["from"])
				var to_type := String(change["to"])
				var had := false
				for i in cur_subtypes.size():
					if cur_subtypes[i] == from_type:
						cur_subtypes[i] = to_type
						had = true
				# "Land — Plains Island" with "plains" rewritten to
				# "island" is an Island, not an "Island Island": a
				# duplicate would hand out the same intrinsic mana ability
				# twice below. Kept in place (first occurrence wins) so the
				# array reset_characteristics() refills is never replaced.
				if had:
					var scan := cur_subtypes.size() - 1
					while scan > 0:
						if cur_subtypes.find(cur_subtypes[scan]) < scan:
							cur_subtypes.remove_at(scan)
						scan -= 1
				for i in cur_landwalk.size():
					if cur_landwalk[i] == from_type:
						cur_landwalk[i] = to_type
				# A land's mana follows the basic land types it carries —
				# ONE intrinsic mana ability per type (CR 305.6), which is
				# why a Tundra taps for {W} or {U}. This used to install a
				# single ability for `to_type` and drop the rest, so
				# Magical Hack on a Tundra ("island" -> "swamp") deleted
				# the {W} the untouched Plains half still grants.
				if had and is_land():
					var intrinsic: Array[ManaAbility] = []
					for subtype in cur_subtypes:
						if Mtg.BASIC_LAND_COLORS.has(subtype):
							intrinsic.append(ManaAbility.new(
								int(Mtg.BASIC_LAND_COLORS[subtype])))
					if not intrinsic.is_empty():
						cur_mana_abilities = intrinsic
			"color_word":
				var from_color := int(change["from"])
				var to_color := int(change["to"])
				if (cur_protection & from_color) != 0:
					cur_protection = (cur_protection & ~from_color) | to_color
			"mana_color":
				var was := int(change["from"])
				var now := int(change["to"])
				var retuned: Array[ManaAbility] = []
				for ability in cur_mana_abilities:
					var swapped := false
					for pair in ability.produces:
						if int(pair[0]) == was:
							swapped = true
					# The copy keeps every rider the ability carries
					# (ManaAbility.retuned); a bare `ManaAbility.new` here
					# used to lose the tap, the cost and the side effect.
					retuned.append(ability.retuned(was, now) if swapped else ability)
				cur_mana_abilities = retuned


## Replace this permanent's live land type and the mana it taps for —
## "enchanted land is a Swamp" (Evil Presence), "nonbasic lands are
## Mountains" (Blood Moon). Called from layer-4 statics during
## recalculation.
##
## CR 305.7: a land whose subtype is changed to a BASIC land type "loses all
## abilities generated from its rules text" and gains the matching mana
## ability. So this drops the activated abilities outright and raises the
## same silencing flag Titania's Song uses for the triggered and static
## ones — under Blood Moon a Strip Mine really is nothing but a Mountain.
## The card is still a land and still has its name.
func become_basic_land_type(land_type: String, color: int) -> void:
	cur_subtypes = [land_type]
	cur_mana_abilities = [ManaAbility.new(color)]
	cur_activated_abilities.clear()
	cur_abilities_silenced = true


## Live keyword check (use this, not data.has_keyword, in rules code).
func has_keyword(keyword: int) -> bool:
	return cur_keywords.has(keyword)


## Give this creature "bands with other [param desc]" for the rest of the
## recalculation — [param filter] is the quality, and this creature is
## expected to have it too (the printed grants only reach creatures that
## do). The same grant from two sources counts once.
func grant_bands_with(desc: String, filter: Callable) -> void:
	for entry in cur_bands_with:
		if String(entry["desc"]) == desc:
			return
	cur_bands_with.append({"desc": desc, "filter": filter})


## Live COLOUR check: does this object have ANY of [param color_mask]'s
## colours right now? (Use this, not data.color_mask(), in rules code —
## a Deathlaced Serra Angel really is a legal Terror target.)
func has_color(color_mask: int) -> bool:
	return (cur_colors & color_mask) != 0


## True when this object has no colour at all (artifacts, Ornithopter, and
## anything a Lace has painted colourless).
func is_colorless() -> bool:
	return cur_colors == 0


## LIVE type checks — what the object IS right now (an animated Mishra's
## Factory is a creature; its printed data never was). Rules code uses
## these for anything on the battlefield.
func is_creature() -> bool:
	return (cur_types & Mtg.CardType.CREATURE) != 0

## Live land-ness — an animated Mishra's Factory is still a land.
func is_land() -> bool:
	return (cur_types & Mtg.CardType.LAND) != 0

## Live type check against the CURRENT type mask.
func is_type(type_flag: int) -> bool:
	return (cur_types & type_flag) != 0

## Live subtype check (lowercase) — Blood Moon really does make a
## nonbasic land a "mountain" for everything that asks.
func has_subtype(subtype: String) -> bool:
	return cur_subtypes.has(subtype)


## Would this creature die to marked damage? (State-based action 704.5g.)
##
## LIVE type, like every other rules read (CONTRIBUTING.md rule 5). It asked
## `data.is_creature()` until 2026-09-01, which answered `false` for an
## animated Mishra's Factory or a Kormus Bell'd Swamp sitting on lethal
## damage. Nothing called it then — MtgGame's own state-based-action pass
## does this check inline — so the bug was a trap for the next caller
## rather than a live one.
func has_lethal_damage() -> bool:
	return is_creature() and zone == Mtg.Zone.BATTLEFIELD \
		and damage >= cur_toughness


## Is this object an Aura? The printed answer (CardData.is_aura) unless it
## returned to the battlefield as a non-Aura enchantment ([member
## lost_enchant]).
func is_aura() -> bool:
	return data.is_aura() and not lost_enchant


## Reset battlefield state when leaving the battlefield — a card in the
## graveyard remembers nothing (CR 400.7) — but first snapshot the live
## power/toughness into [member last_power] / [member last_toughness].
func clear_battlefield_state() -> void:
	# LAST KNOWN INFORMATION (CR 608.2h) must be captured BEFORE the wipe.
	last_power = cur_power
	last_toughness = cur_toughness
	last_types = cur_types
	last_colors = cur_colors
	last_subtypes = cur_subtypes.duplicate()
	tapped = false
	damage = 0
	summoning_sick = false
	attached_to = -1
	lost_enchant = false
	controlled_via = -1
	leash_needs_tapped = false
	leash_power_capped = false
	attachments.clear()
	counters.clear()
	damaged_by_this_turn.clear()
	damage_from_this_turn.clear()
	damaged_players_this_turn.clear()
	regeneration_shields = 0
	destruction_shields = 0
	damage_eats_counters = ""
	damage_all_redirect_to = -1
	regeneration_banned_this_turn = false
	damage_unpreventable_this_turn = false
	prevention = 0
	attacked_this_turn = false
	could_attack_this_turn = false
	blocked_this_turn = false
	blocked_ids_this_turn.clear()
	must_block_this_turn = false
	extra_blocks_this_turn = 0
	must_attack_this_turn = false
	damage_redirect_to = -1
	damage_redirects = 0
	damage_redirect_sources.clear()
	damage_point_redirect_to = -1
	damage_point_redirects = 0
	removed_keywords.clear()
	added_keywords.clear()
	added_types = 0
	added_protection = 0
	phased_out = false
	face_down = false
	exile_instead_of_dying = false
	text_changes.clear()
	color_override = -1   # colour changes end with the zone change (CR 400.7)
	cant_attack_next_turn = false
	cant_attack_this_turn = false
	ability_uses.clear()
	memory.clear()
	skip_next_untap = false
	skip_untaps = 0
	controller_id = owner_id
	reset_characteristics()


## Stop being a copy (CR 707.2 — a copy is only a copy on the battlefield).
## Deliberately NOT part of [method clear_battlefield_state]: the zone-change
## helpers call it only AFTER the departing object's own leave- and
## dies-triggers have been offered the event, so a Clone of Onulet still pays
## out its borrowed trigger (CR 608.2h last known information).
func restore_printed_identity() -> void:
	if printed_data != null and data != printed_data:
		data = printed_data
		reset_characteristics()


func _to_string() -> String:
	return "%s#%d" % [data.card_name, id]
