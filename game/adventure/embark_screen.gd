class_name EmbarkScreen
extends Control
## EMBARK TO THE WORLD OF SHANDALAR — the new adventure's one screen
## (owner design, 2026-10-22): the hero's face, their name, the figure
## that walks the map, the colour of their magic, their playmat, the card
## packs that join and the difficulty — 1997's own choices — and the
## CAMPAIGN SETTINGS, the modern rules, behind one button (the owner,
## 2026-10-29: *"we just make a button called 'campaign settings' with a
## popup and all modern settings with short explanations there"*; [method
## open_settings]), then `Adventure` or `Leave`.
##
## THE 1997 GAME ASKED ON THREE SCREENS and 1.3 on five (difficulty,
## colour, the face designer, the name; `RunAdventureSession`); here it is
## one, so every choice is in view while the others are made, and a
## second adventure opens on the first one's hero ([AdventureSetup],
## which holds every choice and turns them into the world's record).
##
## THE GROUND IS THE 1997 PORTRAIT SCREEN'S: `Menu4.pic`, the dark
## scratched field with its dark red veins the faces stood on (imported as
## `adventure_hero_background`), so the panels are dark and the lettering
## light, and the face is chosen with red arrows ([RedArrow]). Without the
## picture the field is the same dark red-brown, flat.
##
## WHAT `Adventure` DOES TODAY: it checks the hero, remembers every choice
## and makes the record the world will be built from — and says so,
## because the world itself is the next piece of M5
## (`docs/adventure-implementation-notes.md`).

signal embarked(record: Dictionary)

const TITLE := "Embark to the world of Shandalar…"
const BACKGROUND_KEY := "adventure_hero_background"
const FLAT := Color8(34, 20, 18)

const PARCHMENT := Color8(236, 222, 196)
const DIM := Color8(176, 160, 136)
const GOLD := Color8(232, 190, 110)
const GARNET := Color8(112, 34, 26)

## The face at twice its 1997 size (137 × 169), the size 1.3 showed the
## finished face on its pedestal (`RunFacemakerFlow`).
const PORTRAIT_SIZE := Vector2(250, 308)
const SYMBOL_CELL := 48
const SYMBOL_SIZE := Vector2(60, 60)
## The board half's own proportions (914 × 400), as the battle-setup
## screen's preview keeps them, so a picture is cropped here as there — at
## its size again since the rules moved into the Campaign Settings
## (2026-10-29; three quarters of it, 240 × 105, while four rules stood
## under it in the column, 2026-10-28).
const PLAYMAT_PREVIEW := Vector2(320, 140)
## The narrowest the three windows go; on the 1280-wide layout each is a
## third of the row.
const PANEL_WIDTH := 370.0

## Each level's plain word in its own ink, from green for a training game
## to red for a hard one ([constant AdventureSetup.DIFFICULTY_WORDS]).
const DIFFICULTY_INKS: Array[Color] = [Color8(150, 214, 126), Color8(222, 208, 118),
	Color8(238, 164, 78), Color8(238, 92, 62)]

## A colour's name in letters that read on the dark field — black's own
## would not, so it is the pale violet of its mana.
const COLOR_INKS := {
	"white": Color8(244, 238, 222), "blue": Color8(120, 168, 238),
	"black": Color8(184, 160, 204), "red": Color8(238, 96, 64),
	"green": Color8(120, 204, 112),
}

var setup := AdventureSetup.new()
## The faces in the order the chooser walks them ([method faces]).
var _faces: Array[Dictionary] = []
## Whether the name follows the face: true while the field holds the
## face's own suggestion or nothing, false once the player types a name.
var _name_follows := true
var _leaving := false
## The thread making the world behind the veil ([method _make_world_aside]).
var _worker: Thread
var _popup: Control = null

var _portrait: TextureRect
var _portrait_caption: Label
var _arrows: Array[RedArrow] = []
var _name_edit: LineEdit
var _walker_buttons: Array[Button] = []
var _color_buttons: Array[Button] = []
var _color_name: Label
var _color_flavor: Label
var _color_gifts: Label
var _playmat_color: OptionButton
var _card_rule: OptionButton
## The copy limit's words, on and off, and its tooltip.
## THE CARD RULES, named as the owner named them (2026-10-24), by
## [constant AdventurePlayer.CARD_RULES]; what each does is its tooltip.
const RULE_NAMES := {
	AdventurePlayer.RULE_MEANT: "Adventure limit of cards (as intended in 1997)",
	AdventurePlayer.RULE_SHIPPED: "No limit (as shipped in 1997)",
	AdventurePlayer.RULE_CLASSIC: "Classic MTG rules",
}
const RULE_TIPS := {
	AdventurePlayer.RULE_MEANT: "The shops and the duels' rewards offer no card your deck in use already holds as many copies of as its size allows: one under 40 cards, two from 40, three from 60, one more with Tome of Enlightenment — as the 1997 game meant.",
	AdventurePlayer.RULE_SHIPPED: "The shops and the duels' rewards offer any number of copies, as the 1997 game really did.",
	AdventurePlayer.RULE_CLASSIC: "A deck holds at most four copies of a card, basic lands aside; one of a restricted card, four with Tome of Enlightenment; none of a banned one, by the ban list below. No shop, trader, reward or lair offers you a card you already own as many copies of as a deck may hold.",
}
## THE FINAL BATTLE'S RULE (the owner, 2026-10-27: "A setting at Embark"),
## by [constant AdventurePlayer.LIFE_RULES], named as the owner named them;
## what each does is its tooltip.
var _life_rule: OptionButton
const LIFE_NAMES := {
	AdventurePlayer.LIFE_RELOAD: "Reload allowed",
	AdventurePlayer.LIFE_ONE: "One life",
}
const LIFE_TIPS := {
	AdventurePlayer.LIFE_RELOAD: "Your adventure is saved at Arzakon's door as the final battle begins. Lose it, and loading the adventure puts you back at his door to face him again; every battle lost is written in your record.",
	AdventurePlayer.LIFE_ONE: "One final battle: lose it, or leave or close the game during it, and the adventure is over for good, its save marked failed. No save of it can fight the battle again.",
}
## THE CARD HOLD (the owner, 2026-10-28: "A new Embark setting: card hold —
## '1997 card hold limit' / 'unlimited card hold'"), by [constant
## AdventurePlayer.CARD_HOLDS], named as the owner named them; what each
## does is its tooltip, and the arrival says the one chosen.
var _card_hold: OptionButton
const HOLD_NAMES := {
	AdventurePlayer.HOLD_1997: "1997 card hold limit",
	AdventurePlayer.HOLD_UNLIMITED: "Unlimited card hold",
}
const HOLD_TIPS := {
	AdventurePlayer.HOLD_1997: "Your magic bag holds 500 cards, as in 1997. With it full, a card you win or find is lost, the shops, traders and the wise man give you nothing more, and a dungeon's treasure asks you to leave one of your cards in its place.",
	AdventurePlayer.HOLD_UNLIMITED: "Your magic bag holds any number of cards: no card is ever lost or refused for a full bag.",
}
const HOLD_SUMMARY := {
	AdventurePlayer.HOLD_1997: "Card hold: 500 cards, as in 1997.",
	AdventurePlayer.HOLD_UNLIMITED: "Card hold: unlimited, your magic bag holds any number of cards.",
}
## THE BAN LIST of the Classic MTG rules (the owner, 2026-10-28: "an Embark
## setting (Embark only) with three lists"), by [constant ClassicBans.LISTS],
## named as the owner named them; greyed, its tooltip saying why, unless the
## card rule is the Classic MTG rules, the one rule that reads it.
var _ban_list: OptionButton
var _ban_words: Label
const BAN_NAMES := {
	ClassicBans.OLD: "1998 (the original game's)",
	ClassicBans.BOTH: "1998 + modern",
	ClassicBans.MODERN: "Modern",
}
const BAN_TIPS := {
	ClassicBans.OLD: "The lists of the original game's day: the Classic (Type 1) banned and restricted lists of January 1998, as The Duelist #22 printed them. Banned: Channel, Divine Intervention, Mind Twist and the ante cards. Restricted: Black Lotus, the Moxen, Sol Ring, Black Vise, Berserk, Regrowth, Strip Mine and others; Mana Crypt, Mana Vault and Time Vault are not.",
	ClassicBans.BOTH: "Never looser than either list: a card banned in 1998 or today is banned, one restricted in 1998 or today is restricted. Channel, Divine Intervention and Mind Twist are banned; Mana Crypt, Mana Vault, Time Vault and Black Vise are restricted.",
	ClassicBans.MODERN: "Today's Vintage lists, for this game's cards. Restricted: Black Lotus, the Moxen, Sol Ring, Mana Crypt, Mana Vault, Time Vault, Channel, Demonic Tutor, Strip Mine and others. Banned: the ante cards and seven cards with offensive art or text. Mind Twist, Black Vise and Berserk are free.",
}
const BAN_GREYED := "Only the Classic MTG rules read a ban list: choose them as your card rule to use one."
## [QoL] Broader paid-trader selections, chosen per campaign; off by default.
var _all_trader_cards: CheckBox
const TRADER_BOX := "All cards offered by traders"
const TRADER_TIP := "Town traders, the Nomad's Bazaar and the Diamond Mine can offer every card in this adventure's pool, including special cards and dungeon treasures. Town categories, Classic bans and copy limits still apply. Shops and free rewards are unchanged."
const TRADER_ON_LINE := "Special cards and treasures can be traded."
const TRADER_OFF_LINE := "Traders keep their original selection."
## THE SIEGES' PACE [ours, the owner's ruling of 2026-10-28 on 1997's
## complaint: "creatures siege towns too much and they cannot explore"], by
## [constant AdventurePlayer.SIEGE_PACES] ([Sieges]); what each does is its
## tooltip, and the arrival says the one chosen. A row of the Campaign
## Settings (it stood under the difficulty until they were made).
var _sieges: OptionButton
const SIEGE_NAMES := {
	AdventurePlayer.SIEGES_1997: "As 1997",
	AdventurePlayer.SIEGES_STEADY: "Steady",
	AdventurePlayer.SIEGES_RARE: "Rare",
	AdventurePlayer.SIEGES_NONE: "None",
}
const SIEGE_TIPS := {
	AdventurePlayer.SIEGES_1997: "The wizards' sieges as in 1997: each comes sooner than the last. Late in the game a town is besieged about every half minute of walking, with a quarter of a minute to lift the siege.",
	AdventurePlayer.SIEGES_STEADY: "A siege about every two minutes of walking, never faster, with about 45 seconds to lift it. 1997's sieges came faster with every one.",
	AdventurePlayer.SIEGES_RARE: "A siege about every four minutes of walking, never faster, with about a minute and a half to lift it.",
	AdventurePlayer.SIEGES_NONE: "The wizards never besiege a town: no town is lost to them and no wizard casts the Spell of Dominion. Your quest is still the five castles and Arzakon.",
}
const SIEGE_SUMMARY := {
	AdventurePlayer.SIEGES_1997: "Sieges: as in 1997, each sooner than the last.",
	AdventurePlayer.SIEGES_STEADY: "Sieges: steady, about one every two minutes of walking.",
	AdventurePlayer.SIEGES_RARE: "Sieges: rare, about one every four minutes of walking.",
	AdventurePlayer.SIEGES_NONE: "Sieges: none, no town is ever besieged.",
}
## THE CREATURES' WAY [ours, the owner's ruling of 2026-10-29], by
## [constant AdventurePlayer.CREATURE_WAYS] ([WorldCreatures]). Notice's
## ranges are the nearest creature's; every other notices the hero at half
## of its own ([method WorldCreatures.notice_range], slots.c 706–708) — the
## tip says so (the 0.50.66 bug campaign, h3-3).
var _creatures: OptionButton
const CREATURE_NAMES := {
	AdventurePlayer.CREATURES_HUNT: "Hunt",
	AdventurePlayer.CREATURES_NOTICE: "Notice",
}
const CREATURE_TIPS := {
	AdventurePlayer.CREATURES_HUNT: "As the 1997 game played: every creature on the map comes at you, every moment, from wherever it is. Only a road outruns the slower ones.",
	AdventurePlayer.CREATURES_NOTICE: "The 1997 game's own design, which it never switched on: a creature wanders its own lands until you come within its range (a tile and a half for a wizard, up to four and a half for a troll or a wyrm, twice that for a few wide-ranging ones; that is for the creature nearest you, the others notice you at half that), then hurries at you. Some are slowed on certain lands: a Merfolk Shaman in black swamps, a Sedge Beast in green forests.",
}
const CREATURE_SUMMARY := {
	AdventurePlayer.CREATURES_HUNT: "Creatures: they hunt you from anywhere, as in 1997.",
	AdventurePlayer.CREATURES_NOTICE: "Creatures: they notice you as you come near.",
}
## THE DUELS' STARTING LIFE [ours, the owner's ruling of 2026-10-29], by
## [constant AdventurePlayer.LIFE_STARTS].
var _life_start: OptionButton
const START_NAMES := {
	AdventurePlayer.START_LINKS: "Links only",
	AdventurePlayer.START_BASE: "Base 10 + links",
}
const START_TIPS := {
	AdventurePlayer.START_LINKS: "As the 1997 game played: every adventure duel starts with a life for each town or city whose mana you have linked (ten to begin with), and any bonus for the next duel.",
	AdventurePlayer.START_BASE: "The 1997 game's own design, which it never switched on: every adventure duel starts at 10 life, 2 more with Haggler's Coin, 3 with Ring of the Guardian, 5 with Fruit of Sustenance, then a life for each mana link and any bonus for the next duel. A new hero starts duels at 20.",
}
const START_SUMMARY := {
	AdventurePlayer.START_LINKS: "Starting life: a life for each mana link, as in 1997.",
	AdventurePlayer.START_BASE: "Starting life: 10, and the World Magics' bonuses, before your mana links.",
}
## THE ASCETIC HERO [ours, the owner's ruling of 2026-10-29]: a box.
var _ascetic: CheckBox
const ASCETIC_BOX := "Eat half as much"
const ASCETIC_TIP := "Your hero eats half as much: food lasts twice as long. Fruit of Sustenance still gives its food in the forests; with none left you still walk slower."
const ASCETIC_ON_LINE := "Your hero eats half as much: food lasts twice as long."
const ASCETIC_OFF_LINE := "Your hero eats a food every few steps, as in 1997."
const ASCETIC_SUMMARY := "Ascetic hero: your food lasts twice as long."
## THE ROWS' PLAIN LINES, always shown under each choice in the Campaign
## Settings (the owner, 2026-10-29: "all modern settings with short
## explanations there") — what the one chosen does, in a line; the
## tooltips say it whole.
const LIFE_LINES := {
	AdventurePlayer.LIFE_RELOAD: "Lose to Arzakon and you face him again from his door.",
	AdventurePlayer.LIFE_ONE: "Lose the final battle and the adventure is over for good.",
}
const RULE_LINES := {
	AdventurePlayer.RULE_MEANT: "No shop or reward offers more copies than your deck's size allows.",
	AdventurePlayer.RULE_SHIPPED: "Shops and rewards offer any number of copies, as 1997 really did.",
	AdventurePlayer.RULE_CLASSIC: "Four copies of a card, one of a restricted card, none of a banned one.",
}
const BAN_LINES := {
	ClassicBans.OLD: "The Classic lists of January 1998, the original game's day.",
	ClassicBans.BOTH: "Banned or restricted in 1998 or today: never looser than either.",
	ClassicBans.MODERN: "Today's Vintage lists, for this game's cards.",
}
const BAN_GREYED_LINE := "Read only under the Classic MTG rules."
const HOLD_LINES := {
	AdventurePlayer.HOLD_1997: "Your magic bag holds 500 cards; a card won with it full is lost.",
	AdventurePlayer.HOLD_UNLIMITED: "Your magic bag holds any number of cards.",
}
const SIEGE_LINES := {
	AdventurePlayer.SIEGES_1997: "Each siege comes sooner than the last, as in 1997.",
	AdventurePlayer.SIEGES_STEADY: "A siege about every two minutes of walking, never faster.",
	AdventurePlayer.SIEGES_RARE: "A siege about every four minutes of walking.",
	AdventurePlayer.SIEGES_NONE: "No town is ever besieged and no wizard casts Dominion.",
}
const CREATURE_LINES := {
	AdventurePlayer.CREATURES_HUNT: "Every creature comes at you from wherever it is, as in 1997.",
	AdventurePlayer.CREATURES_NOTICE: "Creatures wander until you come near, then hurry at you.",
}
const START_LINES := {
	AdventurePlayer.START_LINKS: "Each duel starts with a life for each of your mana links.",
	AdventurePlayer.START_BASE: "Each duel starts at 10, more with three World Magics, plus links.",
}
## THE LINE UNDER THE BUTTON's words ([method settings_line]).
const SIEGE_SHORT := {
	AdventurePlayer.SIEGES_1997: "Sieges as 1997",
	AdventurePlayer.SIEGES_STEADY: "Steady sieges",
	AdventurePlayer.SIEGES_RARE: "Rare sieges",
	AdventurePlayer.SIEGES_NONE: "No sieges",
}
const CREATURE_SHORT := {
	AdventurePlayer.CREATURES_HUNT: "Creatures hunt",
	AdventurePlayer.CREATURES_NOTICE: "Creatures notice",
}
const LIFE_SHORT := {
	AdventurePlayer.LIFE_RELOAD: "Reload allowed",
	AdventurePlayer.LIFE_ONE: "One life",
}
const RULE_SHORT := {
	AdventurePlayer.RULE_SHIPPED: "No card limit",
	AdventurePlayer.RULE_CLASSIC: "Classic MTG rules",
}
const START_SHORT := "Base 10 life"
const ASCETIC_SHORT := "Ascetic hero"
const HOLD_SHORT := "Unlimited card hold"
const SETTINGS_TIP := "The campaign's modern settings: open them to read and change each."
## The Campaign Settings: the veil, its window, the button that opens it,
## the line under it, each row's plain line (by its choice's name) and the
## window's two buttons.
var _settings: Control
var _settings_dialog: OriginalDialog
var settings_button: Button
var _settings_summary: Label
var _lines := {}
var _as_1997: Button
var _done: Button
var _playmat_type: OptionButton
var _playmat_preview: Control
var _difficulty_buttons: Array[Button] = []
var _difficulty_word: Label
var _difficulty_note: Label
var _pack_checks: Dictionary = {}
## THE CARD PACKS WAIT (the owner, 2026-10-27: "on the embark Menu gray out
## lack options as they are not implemented!"): a pack's world, ruled by
## its World Lord, is not built yet, so the packs are shown greyed and
## unticked, and nothing chooses them — no tick, All or None, Randomize, nor
## the choice remembered from before. True once the World Lords are built
## (the tests set it to try the choice).
static var packs_ready := false
## What the greyed packs say until then (the owner, 2026-10-28).
const NOT_YET := "Not implemented yet."
var _seed_edit: LineEdit
## The walking figure: its preview on the portrait, the six part swatches
## and the popup a swatch opens ([HeroColors]).
var _figure_preview: FigurePreview
var _figure_swatches: Array[Button] = []
var _figure_popup: PopupPanel
var _seed_row: Control
## The bottom strip: `Leave`, the seed and `Adventure`.
var _bar: HBoxContainer
## While the world is made: the strip's hourglass and words, the stars, and
## how long they have shown ([method show_generating]).
var _wait: HBoxContainer
var _wait_stars: Label
var _wait_time := 0.0
var _note: Label
var adventure_button: Button
var leave_button: Button
var randomize_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	setup = AdventureSetup.restore(_installed_packs())
	if not packs_ready:
		setup.packs.clear()
	_faces = faces()
	if PortraitLibrary.texture(setup.portrait) == null:
		setup.portrait = String(_faces[0]["id"]) if not _faces.is_empty() else ""
	if setup.player_name == "":
		setup.player_name = AdventureSetup.suggested_name(setup.portrait)
	_name_follows = setup.player_name == AdventureSetup.suggested_name(setup.portrait)
	# A NEW WORLD'S SEED FROM THE CLOCK, as the 1997 game seeded its dice,
	# written as the time of day (the owner, 2026-10-22): filled in each time
	# the screen opens, never remembered.
	if setup.seed_text == "":
		setup.seed_text = AdventureSetup.time_seed_text()
	_build()
	_show_all()
	var music := get_node_or_null(^"/root/ShellMusic")
	if music != null:
		music.call(&"play")
	if _arrows.size() == 2 and not _arrows[1].disabled:
		_arrows[1].grab_focus()
	else:
		adventure_button.grab_focus()


## THE FACES IN CHOOSER ORDER: the fourteen 1997 heroes first, in the
## order the original stood them on their pedestals, then every other
## face the game has — the rogues, a face made in 1.3's designer, the
## player's own, ours — as the battle-setup screen lists them.
static func faces() -> Array[Dictionary]:
	var all := PortraitLibrary.all()
	var out: Array[Dictionary] = []
	for row in AdventureSetup.HEROES:
		for face in all:
			if face["id"] == row["id"]:
				out.append(face)
	for face in all:
		if AdventureSetup.hero(String(face["id"])).is_empty():
			out.append(face)
	return out


func _card_packs() -> Node:
	return get_node_or_null(^"/root/CardPacks")


func _installed_packs() -> Array[String]:
	var packs := _card_packs()
	return packs.available_ids() if packs != null else ([] as Array[String])


# ---------------------------------------------------------------- build --

func _build() -> void:
	var art := GameSkin.texture(BACKGROUND_KEY)
	if art != null:
		var ground := TextureRect.new()
		ground.name = "Ground"
		ground.texture = art
		ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		ground.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(ground)
	else:
		var flat := ColorRect.new()
		flat.name = "Ground"
		flat.color = FLAT
		flat.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(flat)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var title := _heading(TITLE, 40)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)

	# THE COLUMNS SCROLL, THE BUTTONS DO NOT — the battle-setup screen's
	# rule: a short window loses neither `Leave` nor `Adventure`.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	page.add_child(scroll)
	# THREE WINDOWS OF ONE SIZE, LINED UP (the owner, 2026-10-22: *"these
	# sub windows should be the same size! And aligned."*): each takes an
	# equal share of the width and the whole height down to the buttons,
	# so their headings sit on one line and their edges meet the edges of
	# `Leave` and `Adventure`. In a window too small for them they keep
	# one width each and the row scrolls.
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	scroll.add_child(columns)
	var panels: Array[Control] = [_panel(_build_hero(), "HeroPanel"),
		_panel(_build_magic(), "MagicPanel"), _panel(_build_journey(), "JourneyPanel")]
	# One floor for all three: the widest one's own, so a window whose
	# contents want more than a third never ends up wider than the others.
	# Measured once they are in the tree, in the fonts they wear there (an
	# Export MPN button measured outside it came out 4 px short on CI).
	for panel in panels:
		columns.add_child(panel)
	var widest := PANEL_WIDTH
	for panel in panels:
		widest = maxf(widest, panel.get_combined_minimum_size().x)
	for panel in panels:
		panel.custom_minimum_size.x = widest

	page.add_child(_build_buttons())
	# The Campaign Settings' window, over everything, shown by its button.
	add_child(_build_settings())


func _build_hero() -> Control:
	var box := _column("Your hero")
	var frame := PanelContainer.new()
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0, 0, 0, 0.45)
	well.border_color = GOLD.darkened(0.35)
	well.set_border_width_all(2)
	well.set_corner_radius_all(4)
	well.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", well)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = PORTRAIT_SIZE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.tooltip_text = "Your face in every adventure duel. Your own pictures go in %s" \
		% PortraitLibrary.ensure_folder()
	frame.add_child(_portrait)
	# The face's name on a band across its foot.
	_portrait_caption = _text("", 15)
	_portrait_caption.name = "FaceName"
	_portrait_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_caption.clip_text = true
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0.04, 0.02, 0.02, 0.72)
	band.set_content_margin_all(2)
	_portrait_caption.add_theme_stylebox_override("normal", band)
	_portrait.add_child(_portrait_caption)
	_portrait_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_portrait_caption.offset_top = -24

	# THE RED ARROWS BESIDE THE FACE (the owner, 2026-10-22: *"move the red
	# arrows to each side of portrait. And you gain vertical space"*).
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var back := RedArrow.new(-1, 38.0)
	back.name = "PreviousFace"
	back.tooltip_text = "The face before."
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(step_face.bind(-1))
	row.add_child(back)
	row.add_child(frame)
	var forward := RedArrow.new(1, 38.0)
	forward.name = "NextFace"
	forward.tooltip_text = "The face after."
	forward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	forward.pressed.connect(step_face.bind(1))
	row.add_child(forward)
	_arrows = [back, forward]
	box.add_child(row)

	box.add_child(_label("Name"))
	_name_edit = LineEdit.new()
	_name_edit.name = "HeroName"
	_name_edit.max_length = AdventureSetup.NAME_MAX
	_name_edit.placeholder_text = "Your hero's name"
	_name_edit.tooltip_text = "Up to %d characters. A 1997 hero comes with their own name; type yours over it." \
		% AdventureSetup.NAME_MAX
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: embark())
	box.add_child(_name_edit)
	_note = _text("", 14)
	_note.name = "Note"
	_note.add_theme_color_override("font_color", Color8(240, 120, 96))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	box.add_child(_note)

	box.add_child(_label("On the map"))
	var walkers := HBoxContainer.new()
	walkers.alignment = BoxContainer.ALIGNMENT_CENTER
	walkers.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for i in AdventureSetup.WALKERS.size():
		var button := _toggle(AdventureSetup.WALKER_LABELS[i], Vector2(96, 34), 16, group)
		button.name = "Walker" + AdventureSetup.WALKER_LABELS[i]
		button.tooltip_text = [
			"The man who walks the world map.",
			"The woman who walks the world map.",
			"One of the two, drawn when the world is made."][i]
		button.pressed.connect(choose_walker.bind(AdventureSetup.WALKERS[i]))
		walkers.add_child(button)
		_walker_buttons.append(button)
	box.add_child(walkers)
	# THE FIGURE'S COLOURS (the owner, 2026-10-22): a swatch a part, each
	# opening the part's colours, and 1997 for the old game's own figure.
	var dress := HBoxContainer.new()
	dress.name = "FigureColors"
	dress.alignment = BoxContainer.ALIGNMENT_CENTER
	dress.add_theme_constant_override("separation", 4)
	for i in HeroColors.PARTS.size():
		var swatch := Button.new()
		swatch.name = "Figure" + HeroColors.PART_NAMES[i]
		swatch.text = HeroColors.PART_NAMES[i]
		swatch.custom_minimum_size = Vector2(46, 28)
		swatch.add_theme_font_size_override("font_size", 11)
		swatch.focus_mode = Control.FOCUS_ALL
		swatch.pressed.connect(open_figure_colors.bind(i))
		dress.add_child(swatch)
		_figure_swatches.append(swatch)
	var original := UiChrome.menu_button("1997", Vector2(62, 28), 13)
	original.name = "FigureOriginal"
	original.tooltip_text = "The figure in the 1997 game's own colors."
	original.pressed.connect(reset_figure_colors)
	dress.add_child(original)
	box.add_child(dress)
	# The hero as they will walk the map, under their colours (the owner,
	# 2026-10-22: *"move mini figurine preview below the color choices"*).
	_figure_preview = FigurePreview.new()
	_figure_preview.name = "FigurePreview"
	_figure_preview.custom_minimum_size = Vector2(96, 74)
	_figure_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_figure_preview)
	return box


func _build_magic() -> Control:
	var box := _column("Your magic")
	var symbols := HBoxContainer.new()
	symbols.alignment = BoxContainer.ALIGNMENT_CENTER
	symbols.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for row in AdventureSetup.COLORS:
		var button := _symbol_button(row, group)
		symbols.add_child(button)
		_color_buttons.append(button)
	box.add_child(symbols)
	_color_name = _heading("", 34)
	_color_name.name = "ColorName"
	_color_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_color_name)
	_color_flavor = _text("", 16)
	_color_flavor.name = "ColorFlavor"
	_color_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_color_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_color_flavor.custom_minimum_size.y = 46
	box.add_child(_color_flavor)
	_color_gifts = _text("", 14)
	_color_gifts.name = "ColorGifts"
	_color_gifts.add_theme_color_override("font_color", GOLD)
	_color_gifts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_color_gifts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_color_gifts)

	box.add_child(HSeparator.new())
	box.add_child(_heading("Your playmat", 22))
	var pickers := HBoxContainer.new()
	pickers.add_theme_constant_override("separation", 8)
	_playmat_color = OptionButton.new()
	_playmat_color.name = "PlaymatColor"
	_playmat_color.add_item("Your color")
	_playmat_color.set_item_metadata(0, "")
	for row in AdventureSetup.COLORS:
		_playmat_color.add_item(String(row["name"]))
		_playmat_color.set_item_metadata(_playmat_color.item_count - 1, String(row["key"]))
	_playmat_color.tooltip_text = "The color of your half of the table in adventure duels."
	_playmat_color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_playmat_color.item_selected.connect(func(index: int) -> void:
		setup.playmat_color = String(_playmat_color.get_item_metadata(index))
		_show_playmat())
	pickers.add_child(_playmat_color)
	_playmat_type = OptionButton.new()
	_playmat_type.name = "PlaymatStyle"
	_playmat_type.add_item(AdventureSetup.RANDOM_TYPE)
	for entry in DuelOptions.TERRITORY_TYPES:
		_playmat_type.add_item(String(entry["label"]))
	_playmat_type.tooltip_text = "Which of the color's three grounds. Random: one of them, drawn when the world is made, as in 1997 (the picture shows one of the three)."
	_playmat_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_playmat_type.item_selected.connect(func(index: int) -> void:
		setup.playmat_type = _playmat_type.get_item_text(index)
		_show_playmat())
	pickers.add_child(_playmat_type)
	box.add_child(pickers)
	var well := PanelContainer.new()
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color(0, 0, 0, 0.5)
	edge.border_color = GOLD.darkened(0.35)
	edge.set_border_width_all(2)
	edge.set_content_margin_all(2)
	well.add_theme_stylebox_override("panel", edge)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_playmat_preview = Control.new()
	_playmat_preview.name = "PlaymatPreview"
	_playmat_preview.custom_minimum_size = PLAYMAT_PREVIEW
	_playmat_preview.clip_contents = true
	well.add_child(_playmat_preview)
	box.add_child(well)
	# THE CAMPAIGN SETTINGS, under the playmat (the owner's ruling of
	# 2026-10-29): the modern rules — the four that stood here under "Your
	# rules", the sieges' pace, the creatures' way, the starting life, the
	# ascetic hero — behind one button, the Embark's own, and under it a
	# line of what is chosen (the whole in its tooltip).
	box.add_child(HSeparator.new())
	settings_button = UiChrome.menu_button(SETTINGS_BUTTON, Vector2(260, 40), 20)
	settings_button.name = "CampaignSettings"
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_button.pressed.connect(open_settings)
	box.add_child(settings_button)
	_settings_summary = _text("", 14)
	_settings_summary.name = "CampaignSummary"
	_settings_summary.add_theme_color_override("font_color", DIM)
	_settings_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_settings_summary.clip_text = true
	_settings_summary.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_settings_summary)
	return box


func _build_journey() -> Control:
	var box := _column("Difficulty")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var group := ButtonGroup.new()
	for i in AdventureSetup.DIFFICULTIES.size():
		var button := _toggle(AdventureSetup.DIFFICULTIES[i], Vector2(170, 36), 17, group)
		button.name = "Difficulty" + AdventureSetup.DIFFICULTIES[i]
		button.tooltip_text = "%s: %s." % [AdventureSetup.DIFFICULTIES[i],
			AdventureSetup.difficulty_phrase(i)]
		button.pressed.connect(choose_difficulty.bind(i))
		grid.add_child(button)
		_difficulty_buttons.append(button)
	box.add_child(grid)
	_difficulty_word = _heading("", 22)
	_difficulty_word.name = "DifficultyWord"
	box.add_child(_difficulty_word)
	_difficulty_note = _text("", 14)
	_difficulty_note.name = "DifficultyNote"
	_difficulty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_difficulty_note)

	box.add_child(HSeparator.new())
	var installed := AdventureSetup.offered_packs(_installed_packs())
	# The heading with All and None beside it, a row saved for the list: it
	# keeps the column within the screen's height without the skin's
	# smaller lettering too (eight packs, 1280 × 800).
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	var heading := _heading("Card packs", 22)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	if not installed.is_empty():
		for label in ["All", "None"]:
			var button := UiChrome.menu_button(label, Vector2(72, 28), 14)
			button.name = "Packs" + label
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.pressed.connect(choose_all_packs.bind(label == "All"))
			button.disabled = not packs_ready
			header.add_child(button)
	box.add_child(header)
	# The owner's words, 2026-10-22, first and in gold.
	# The owner's words, 2026-10-22, first and in gold — once the packs are
	# built. Until then the packs say nothing of what they will be (the
	# owner, 2026-10-28: "remove explanation for the packs as it will be a
	# surprise, just: Not implemented yet.").
	if packs_ready:
		var challenge := _text("These are additional challenges. The base cards are always present.", 14)
		challenge.name = "PacksChallenge"
		challenge.add_theme_color_override("font_color", GOLD)
		challenge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(challenge)
	var about := _text("Each pack opens its own world on the map, ruled by a World Lord. Defeat the lord and the pack's cards appear everywhere. Your first deck is always base cards."
		if packs_ready else NOT_YET, 13)
	about.name = "PacksAbout"
	about.add_theme_color_override("font_color", DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(about)
	if installed.is_empty():
		var none := _text("No card packs are installed. Options › Card Packs... adds them.", 14)
		none.name = "NoPacks"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(none)
	else:
		var list := VBoxContainer.new()
		list.name = "Packs"
		list.add_theme_constant_override("separation", 0)
		var packs := _card_packs()
		for id in installed:
			var info: Dictionary = packs.info(id)
			var check := CheckBox.new()
			check.name = "Pack_" + id
			check.text = "%s · %s" % [packs.label_for(id), String(info.get("name", id))]
			check.tooltip_text = "%s\nVersion %s" % [String(info.get("description", "")),
				String(info.get("version", "?"))]
			check.add_theme_color_override("font_color", PARCHMENT)
			check.add_theme_color_override("font_hover_color", GOLD)
			check.add_theme_color_override("font_pressed_color", PARCHMENT)
			check.add_theme_color_override("font_hover_pressed_color", GOLD)
			check.add_theme_font_size_override("font_size", 15)
			check.add_theme_icon_override("checked", UiChrome.check_icon(true))
			check.add_theme_icon_override("unchecked", UiChrome.check_icon(false))
			check.button_pressed = id in setup.packs
			check.disabled = not packs_ready
			if not packs_ready:
				check.tooltip_text += "\n" + NOT_YET
			check.toggled.connect(choose_pack.bind(id))
			list.add_child(check)
			_pack_checks[id] = check
		box.add_child(list)
	return box


# ------------------------------------------------------ campaign settings --

## THE CAMPAIGN SETTINGS' WINDOW (the owner, 2026-10-29: *"we just make a
## button called 'campaign settings' with a popup and all modern settings
## with short explanations there"*): the 1997 dark stone of the game's
## dialogs ([OriginalDialog], its own fallback without the skin) over a veil
## that keeps the screen under it from the pointer; a row a setting — its
## name, its choice (a list, a box for the ascetic hero) and under it one
## plain line of what the choice does, always shown (the whole in the
## choice's tooltip) — in the owner's order: [constant SETTING_ROWS]. Its
## buttons: `As 1997` ([method as_1997]: every row the 1997 game's choice,
## [constant AS_1997]) and `Done`; Escape is Done. A choice takes effect as
## it is made; Done only closes. Built once, hidden: the rows' lists are
## the screen's own ([member setup] behind them), there to be read whether
## the window shows or not ([method open_settings], [method close_settings]).
func _build_settings() -> Control:
	_settings = Control.new()
	_settings.name = "CampaignSettingsVeil"
	_settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(dim)
	_settings_dialog = OriginalDialog.create(SETTINGS_TITLE, SETTINGS_SIZE, "panel_dark_stone")
	_settings_dialog.name = "CampaignSettingsWindow"
	var body := _settings_dialog.body()
	body.add_theme_constant_override("separation", SETTINGS_GAP)
	body.add_child(_build_life_rule())
	body.add_child(_build_card_rule())
	body.add_child(_build_ban_list())
	body.add_child(_build_all_trader_cards())
	body.add_child(_build_card_hold())
	body.add_child(_build_sieges())
	body.add_child(_build_creatures())
	body.add_child(_build_life_start())
	body.add_child(_build_ascetic())
	_as_1997 = _settings_dialog.add_button(AS_1997_WORDS)
	_as_1997.name = "As1997"
	_as_1997.custom_minimum_size.x = 120
	_as_1997.tooltip_text = AS_1997_TIP
	_as_1997.pressed.connect(as_1997)
	_done = _settings_dialog.add_button("Done")
	_done.name = "Done"
	_done.custom_minimum_size.x = 120
	_done.pressed.connect(close_settings)
	_settings.add_child(_settings_dialog)
	_show_settings()
	return _settings


## The window's size as made; it grows to what its rows hold ([method
## OriginalDialog.fit_height]) as it opens.
const SETTINGS_SIZE := Vector2(700, 300)
## The rows' spacing, and the width of the names' column.
const SETTINGS_GAP := 8
const SETTING_NAME_WIDTH := 132
const SETTINGS_TITLE := "Campaign Settings"
const SETTINGS_BUTTON := "Campaign Settings..."
## The rows, in the owner's order (2026-10-29), by the names of their
## choices' nodes.
const SETTING_ROWS: Array[String] = ["LifeRule", "CardRule", "BanList", "AllTraderCards", "CardHold", "Sieges",
	"Creatures", "LifeStart", "Ascetic"]
const AS_1997_WORDS := "As 1997"
const AS_1997_TIP := "Every setting as the 1997 game played: reload allowed, no card limit, the 1998 ban list, the original trader selection, a 500-card bag, the 1997 sieges, creatures that hunt you, a life for each mana link, food as it was eaten."
## WHAT "AS 1997" CHOOSES, each row the 1997 game's own: the card rule as
## it shipped (no copy limit), the 500-card bag, the sieges' 1997 clock, the
## creatures hunting, a life for each link, the food as eaten. Two rows had
## no choice in 1997 and take the nearest: the final battle "Reload
## allowed" (1997 ended the program after the battle and its Resume took up
## the last save, from before the fifth castle — a retry from further back,
## never a lost adventure), and the ban list "1998" (read only under the
## Classic MTG rules, which 1997 did not have; the lists of its day).
const AS_1997 := {"life_rule": AdventurePlayer.LIFE_RELOAD, "card_rule": AdventurePlayer.RULE_SHIPPED,
	"ban_list": ClassicBans.OLD, "all_trader_cards": false, "card_hold": AdventurePlayer.HOLD_1997,
	"sieges": AdventurePlayer.SIEGES_1997, "creatures": AdventurePlayer.CREATURES_HUNT,
	"life_start": AdventurePlayer.START_LINKS, "ascetic": false}


## A SETTING'S ROW: its name, dim, in a column of its own and beside it
## [param choice] (named [param base]; the row `<base>Row`, the name
## `<base>Words`), and under the choice its plain line (`<base>Line`,
## [method _explain_line]).
func _setting_row(base: String, words_text: String, choice: Control) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.name = base + "Row"
	row.add_theme_constant_override("separation", 2)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var words := OriginalDialog.label(words_text, 15, true)
	words.name = base + "Words"
	words.custom_minimum_size.x = SETTING_NAME_WIDTH
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(words)
	choice.name = base
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(choice)
	row.add_child(line)
	var under := HBoxContainer.new()
	under.add_theme_constant_override("separation", 10)
	var indent := Control.new()
	indent.custom_minimum_size.x = SETTING_NAME_WIDTH
	under.add_child(indent)
	var said := OriginalDialog.label("", 14)
	said.name = base + "Line"
	said.add_theme_color_override("font_color", OriginalDialog.CHOICE)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	said.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	said.clip_text = true
	under.add_child(said)
	row.add_child(under)
	_lines[base] = said
	return row


## A list of [param keys] by their [param names], for a row.
func _list_of(option: OptionButton, keys: Array[String], names: Dictionary) -> OptionButton:
	for key in keys:
		option.add_item(String(names[key]))
		option.set_item_metadata(option.item_count - 1, key)
	option.fit_to_longest_item = false
	option.clip_text = true
	option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	option.add_theme_font_size_override("font_size", 15)
	return option


## Row [param base]'s plain line: [param text], its tooltip [param tip].
func _explain_line(base: String, text: String, tip := "") -> void:
	var said: Label = _lines.get(base)
	if said == null:
		return
	said.text = text
	said.tooltip_text = tip
	said.mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE


## THE CARD RULE OF THE ADVENTURE (the owner, 2026-10-24: "This should be an
## on off setting during shandalar embark construction!", then "one more
## rule … also classic MTG rules", "name the rules as i named them!"): one
## choice of three ([constant RULE_NAMES], [member AdventureSetup.card_rule],
## [member AdventurePlayer.card_rule]); the tooltip says what the one
## chosen does, the row's line in short.
func _build_card_rule() -> Control:
	_card_rule = _list_of(OptionButton.new(), AdventurePlayer.CARD_RULES, RULE_NAMES)
	var row := _setting_row("CardRule", "Card rule", _card_rule)
	_card_rule.item_selected.connect(func(index: int) -> void:
		choose_card_rule(String(_card_rule.get_item_metadata(index))))
	_show_card_rule()
	return row


## The card rule [param rule] chosen ([constant AdventurePlayer.CARD_RULES]).
func choose_card_rule(rule: String) -> void:
	if rule in AdventurePlayer.CARD_RULES:
		setup.card_rule = rule
	_show_card_rule()
	_show_ban_list()


func _show_card_rule() -> void:
	if _card_rule == null:
		return
	_card_rule.select(AdventurePlayer.CARD_RULES.find(setup.card_rule))
	_card_rule.tooltip_text = String(RULE_TIPS.get(setup.card_rule, ""))
	_explain_line("CardRule", String(RULE_LINES.get(setup.card_rule, "")), _card_rule.tooltip_text)
	_show_settings_summary()


## THE FINAL BATTLE'S RULE (the owner, 2026-10-27, round P3: "A setting at
## Embark" — "Reload allowed" or "One life"; [constant LIFE_NAMES], [member
## AdventureSetup.life_rule], [member AdventurePlayer.life_rule]): the
## Campaign Settings' first row. Not drawn by Randomize, as no setting is.
func _build_life_rule() -> Control:
	_life_rule = _list_of(OptionButton.new(), AdventurePlayer.LIFE_RULES, LIFE_NAMES)
	var row := _setting_row("LifeRule", "Final battle", _life_rule)
	_life_rule.item_selected.connect(func(index: int) -> void:
		choose_life_rule(String(_life_rule.get_item_metadata(index))))
	_show_life_rule()
	return row


## The final battle's rule [param rule] chosen ([constant
## AdventurePlayer.LIFE_RULES]).
func choose_life_rule(rule: String) -> void:
	if rule in AdventurePlayer.LIFE_RULES:
		setup.life_rule = rule
	_show_life_rule()


func _show_life_rule() -> void:
	if _life_rule == null:
		return
	_life_rule.select(maxi(AdventurePlayer.LIFE_RULES.find(setup.life_rule), 0))
	_life_rule.tooltip_text = String(LIFE_TIPS.get(setup.life_rule, ""))
	_explain_line("LifeRule", String(LIFE_LINES.get(setup.life_rule, "")), _life_rule.tooltip_text)
	_show_settings_summary()


## THE BAN LIST (the owner, 2026-10-28: "Ban list: an Embark setting
## (Embark only)"; [constant BAN_NAMES], [member AdventureSetup.ban_list],
## [member AdventurePlayer.ban_list], [ClassicBans]): the row under the card
## rule it serves, greyed unless that rule is the Classic MTG rules
## ([method _show_ban_list]).
func _build_ban_list() -> Control:
	_ban_list = _list_of(OptionButton.new(), ClassicBans.LISTS, BAN_NAMES)
	var row := _setting_row("BanList", "Ban list", _ban_list)
	_ban_words = row.find_child("BanListWords", true, false) as Label
	_ban_list.item_selected.connect(func(index: int) -> void:
		choose_ban_list(String(_ban_list.get_item_metadata(index))))
	_show_ban_list()
	return row


## The ban list [param list] chosen ([constant ClassicBans.LISTS]).
func choose_ban_list(list: String) -> void:
	if list in ClassicBans.LISTS:
		setup.ban_list = list
	_show_ban_list()


func _show_ban_list() -> void:
	if _ban_list == null:
		return
	var read := setup.card_rule == AdventurePlayer.RULE_CLASSIC
	_ban_list.select(maxi(ClassicBans.LISTS.find(setup.ban_list), 0))
	_ban_list.disabled = not read
	_ban_list.focus_mode = Control.FOCUS_ALL if read else Control.FOCUS_NONE
	_ban_words.modulate = Color.WHITE if read else Color(1, 1, 1, 0.45)
	var tip := String(BAN_TIPS.get(setup.ban_list, ""))
	_ban_list.tooltip_text = tip if read else "%s\n\n%s" % [BAN_GREYED, tip]
	_explain_line("BanList", String(BAN_LINES.get(setup.ban_list, "")) if read else BAN_GREYED_LINE,
		_ban_list.tooltip_text)
	var said: Label = _lines.get("BanList")
	if said != null:
		said.modulate = Color.WHITE if read else Color(1, 1, 1, 0.6)
	_fence_settings()
	_show_settings_summary()


## THE CARD HOLD (the owner, 2026-10-28; [constant HOLD_NAMES], [member
## AdventureSetup.card_hold], [member AdventurePlayer.card_hold]).
func _build_card_hold() -> Control:
	_card_hold = _list_of(OptionButton.new(), AdventurePlayer.CARD_HOLDS, HOLD_NAMES)
	var row := _setting_row("CardHold", "Card hold", _card_hold)
	_card_hold.item_selected.connect(func(index: int) -> void:
		choose_card_hold(String(_card_hold.get_item_metadata(index))))
	_show_card_hold()
	return row


## The card hold [param hold] chosen ([constant AdventurePlayer.CARD_HOLDS]).
func choose_card_hold(hold: String) -> void:
	if hold in AdventurePlayer.CARD_HOLDS:
		setup.card_hold = hold
	_show_card_hold()


func _show_card_hold() -> void:
	if _card_hold == null:
		return
	_card_hold.select(maxi(AdventurePlayer.CARD_HOLDS.find(setup.card_hold), 0))
	_card_hold.tooltip_text = String(HOLD_TIPS.get(setup.card_hold, ""))
	_explain_line("CardHold", String(HOLD_LINES.get(setup.card_hold, "")), _card_hold.tooltip_text)
	_show_settings_summary()


## THE SIEGES' PACE ([constant SIEGE_NAMES], [member AdventureSetup.sieges],
## [member AdventurePlayer.sieges]).
func _build_sieges() -> Control:
	_sieges = _list_of(OptionButton.new(), AdventurePlayer.SIEGE_PACES, SIEGE_NAMES)
	var row := _setting_row("Sieges", "Sieges", _sieges)
	_sieges.item_selected.connect(func(index: int) -> void:
		choose_sieges(String(_sieges.get_item_metadata(index))))
	_show_sieges()
	return row


## The sieges' pace [param pace] chosen ([constant AdventurePlayer.SIEGE_PACES]).
func choose_sieges(pace: String) -> void:
	if pace in AdventurePlayer.SIEGE_PACES:
		setup.sieges = pace
	_show_sieges()


func _show_sieges() -> void:
	if _sieges == null:
		return
	_sieges.select(maxi(AdventurePlayer.SIEGE_PACES.find(setup.sieges), 0))
	_sieges.tooltip_text = String(SIEGE_TIPS.get(setup.sieges, ""))
	_explain_line("Sieges", String(SIEGE_LINES.get(setup.sieges, "")), _sieges.tooltip_text)
	_show_settings_summary()


## THE CREATURES' WAY [ours, the owner's ruling of 2026-10-29: "Add, default
## Notice (Recommended)"; [constant CREATURE_NAMES], [member
## AdventureSetup.creatures], [member AdventurePlayer.creatures],
## [WorldCreatures]].
func _build_creatures() -> Control:
	_creatures = _list_of(OptionButton.new(), AdventurePlayer.CREATURE_WAYS, CREATURE_NAMES)
	var row := _setting_row("Creatures", "Creatures", _creatures)
	_creatures.item_selected.connect(func(index: int) -> void:
		choose_creatures(String(_creatures.get_item_metadata(index))))
	_show_creatures()
	return row


## The creatures' way [param way] chosen ([constant
## AdventurePlayer.CREATURE_WAYS]).
func choose_creatures(way: String) -> void:
	if way in AdventurePlayer.CREATURE_WAYS:
		setup.creatures = way
	_show_creatures()


func _show_creatures() -> void:
	if _creatures == null:
		return
	_creatures.select(maxi(AdventurePlayer.CREATURE_WAYS.find(setup.creatures), 0))
	_creatures.tooltip_text = String(CREATURE_TIPS.get(setup.creatures, ""))
	_explain_line("Creatures", String(CREATURE_LINES.get(setup.creatures, "")), _creatures.tooltip_text)
	_show_settings_summary()


## THE DUELS' STARTING LIFE [ours, the owner's ruling of 2026-10-29: "Add,
## default off (Recommended)"; [constant START_NAMES], [member
## AdventureSetup.life_start], [member AdventurePlayer.life_start]].
func _build_life_start() -> Control:
	_life_start = _list_of(OptionButton.new(), AdventurePlayer.LIFE_STARTS, START_NAMES)
	var row := _setting_row("LifeStart", "Starting life", _life_start)
	_life_start.item_selected.connect(func(index: int) -> void:
		choose_life_start(String(_life_start.get_item_metadata(index))))
	_show_life_start()
	return row


## The duels' starting life [param start] chosen ([constant
## AdventurePlayer.LIFE_STARTS]).
func choose_life_start(start: String) -> void:
	if start in AdventurePlayer.LIFE_STARTS:
		setup.life_start = start
	_show_life_start()


func _show_life_start() -> void:
	if _life_start == null:
		return
	_life_start.select(maxi(AdventurePlayer.LIFE_STARTS.find(setup.life_start), 0))
	_life_start.tooltip_text = String(START_TIPS.get(setup.life_start, ""))
	_explain_line("LifeStart", String(START_LINES.get(setup.life_start, "")), _life_start.tooltip_text)
	_show_settings_summary()


## [QoL] Paid traders may include cards withheld by the original game.
func _build_all_trader_cards() -> Control:
	_all_trader_cards = CheckBox.new()
	_all_trader_cards.text = TRADER_BOX
	_all_trader_cards.add_theme_color_override("font_color", OriginalDialog.CHOICE)
	_all_trader_cards.add_theme_color_override("font_hover_color", OriginalDialog.CHOICE_LIT)
	_all_trader_cards.add_theme_color_override("font_pressed_color", OriginalDialog.CHOICE_LIT)
	_all_trader_cards.add_theme_color_override("font_hover_pressed_color", OriginalDialog.CHOICE_LIT)
	_all_trader_cards.add_theme_color_override("font_focus_color", OriginalDialog.CHOICE_LIT)
	_all_trader_cards.add_theme_font_size_override("font_size", 15)
	_all_trader_cards.add_theme_icon_override("checked", UiChrome.check_icon(true))
	_all_trader_cards.add_theme_icon_override("unchecked", UiChrome.check_icon(false))
	_all_trader_cards.tooltip_text = TRADER_TIP
	var row := _setting_row("AllTraderCards", "Traders", _all_trader_cards)
	_all_trader_cards.toggled.connect(choose_all_trader_cards)
	_show_all_trader_cards()
	return row


func choose_all_trader_cards(on: bool) -> void:
	setup.all_trader_cards = on
	_show_all_trader_cards()


func _show_all_trader_cards() -> void:
	if _all_trader_cards == null:
		return
	_all_trader_cards.set_pressed_no_signal(setup.all_trader_cards)
	_explain_line("AllTraderCards", TRADER_ON_LINE if setup.all_trader_cards else TRADER_OFF_LINE, TRADER_TIP)
	_show_settings_summary()


## THE ASCETIC HERO [ours, the owner's ruling of 2026-10-29: "The option
## halves food consumption by the hero"; [member AdventureSetup.ascetic],
## [member AdventurePlayer.ascetic]]: a box, off by default.
func _build_ascetic() -> Control:
	_ascetic = CheckBox.new()
	_ascetic.text = ASCETIC_BOX
	_ascetic.add_theme_color_override("font_color", OriginalDialog.CHOICE)
	_ascetic.add_theme_color_override("font_hover_color", OriginalDialog.CHOICE_LIT)
	_ascetic.add_theme_color_override("font_pressed_color", OriginalDialog.CHOICE_LIT)
	_ascetic.add_theme_color_override("font_hover_pressed_color", OriginalDialog.CHOICE_LIT)
	_ascetic.add_theme_color_override("font_focus_color", OriginalDialog.CHOICE_LIT)
	_ascetic.add_theme_font_size_override("font_size", 15)
	_ascetic.add_theme_icon_override("checked", UiChrome.check_icon(true))
	_ascetic.add_theme_icon_override("unchecked", UiChrome.check_icon(false))
	_ascetic.tooltip_text = ASCETIC_TIP
	var row := _setting_row("Ascetic", "Ascetic hero", _ascetic)
	_ascetic.toggled.connect(choose_ascetic)
	_show_ascetic()
	return row


## The ascetic hero chosen ([param on]) or not.
func choose_ascetic(on: bool) -> void:
	setup.ascetic = on
	_show_ascetic()


func _show_ascetic() -> void:
	if _ascetic == null:
		return
	_ascetic.set_pressed_no_signal(setup.ascetic)
	_explain_line("Ascetic", ASCETIC_ON_LINE if setup.ascetic else ASCETIC_OFF_LINE, ASCETIC_TIP)
	_show_settings_summary()


## Every row shown as [member setup] holds it.
func _show_settings() -> void:
	_show_life_rule()
	_show_card_rule()
	_show_ban_list()
	_show_all_trader_cards()
	_show_card_hold()
	_show_sieges()
	_show_creatures()
	_show_life_start()
	_show_ascetic()


## "AS 1997": every row the 1997 game's choice ([constant AS_1997]), at once.
func as_1997() -> void:
	setup.life_rule = String(AS_1997["life_rule"])
	setup.card_rule = String(AS_1997["card_rule"])
	setup.ban_list = String(AS_1997["ban_list"])
	setup.all_trader_cards = bool(AS_1997["all_trader_cards"])
	setup.card_hold = String(AS_1997["card_hold"])
	setup.sieges = String(AS_1997["sieges"])
	setup.creatures = String(AS_1997["creatures"])
	setup.life_start = String(AS_1997["life_start"])
	setup.ascetic = bool(AS_1997["ascetic"])
	_show_settings()


## THE WINDOW OPENS: over the screen, grown to its rows, the keyboard (and
## a pad's D-pad) on its first row and kept inside it ([method
## _fence_settings]).
func open_settings() -> void:
	if _settings == null or _leaving:
		return
	_show_settings()
	_settings.visible = true
	_settings_dialog.fit_height()
	_settings_dialog.keep_on_screen()
	_fence_settings()
	_life_rule.grab_focus()


## Done (or Escape): the window closes, the keyboard back on its button.
func close_settings() -> void:
	if _settings == null or not _settings.visible:
		return
	_settings.visible = false
	if settings_button != null and settings_button.is_inside_tree():
		settings_button.grab_focus()


## Whether the Campaign Settings' window is up.
func settings_shown() -> bool:
	return _settings != null and _settings.visible


## THE RING STAYS IN THE WINDOW: Up and Down (and Tab) walk its rows, the
## greyed ban list passed over, round to the buttons and back; Left and
## Right walk the buttons (UiChrome's fence, a column of it).
func _fence_settings() -> void:
	if _settings_dialog == null or _done == null:
		return
	var ring: Array[Control] = []
	for base in SETTING_ROWS:
		var choice := _settings_dialog.find_child(base, true, false) as Control
		if choice != null and choice.focus_mode != Control.FOCUS_NONE:
			ring.append(choice)
	var last_row := ring.size()
	ring.append(_as_1997)
	ring.append(_done)
	var count := ring.size()
	for i in count:
		var here := ring[i]
		var up := ring[(i - 1 + count) % count]
		var down := ring[(i + 1) % count]
		here.focus_neighbor_top = here.get_path_to(up)
		here.focus_neighbor_bottom = here.get_path_to(down)
		here.focus_previous = here.get_path_to(up)
		here.focus_next = here.get_path_to(down)
		if i < last_row:
			here.focus_neighbor_left = here.get_path_to(here)
			here.focus_neighbor_right = here.get_path_to(here)
	_as_1997.focus_neighbor_left = _as_1997.get_path_to(_done)
	_as_1997.focus_neighbor_right = _as_1997.get_path_to(_done)
	_done.focus_neighbor_left = _done.get_path_to(_as_1997)
	_done.focus_neighbor_right = _done.get_path_to(_as_1997)


## THE LINE UNDER THE BUTTON ([constant SETTING_SHORT]): the sieges, the
## creatures and the final battle, then whatever else is not the default
## — "Steady sieges · Creatures notice · Reload allowed"; one line, cut
## short with "…" when it cannot hold them all ([method settings_words]
## names every one, its tooltip).
static func settings_line(chosen: AdventureSetup) -> String:
	var parts: Array[String] = [String(SIEGE_SHORT[AdventurePlayer.sieges_of(chosen.sieges)]),
		String(CREATURE_SHORT[AdventurePlayer.creatures_of(chosen.creatures)]),
		String(LIFE_SHORT[AdventurePlayer.life_rule_of(chosen.life_rule)])]
	if RULE_SHORT.has(chosen.card_rule):
		parts.append(String(RULE_SHORT[chosen.card_rule]))
	if chosen.life_start == AdventurePlayer.START_BASE:
		parts.append(START_SHORT)
	if chosen.ascetic:
		parts.append(ASCETIC_SHORT)
	if chosen.card_hold == AdventurePlayer.HOLD_UNLIMITED:
		parts.append(HOLD_SHORT)
	if chosen.all_trader_cards:
		parts.append("All trader cards")
	return " · ".join(parts)


## Every setting in full words, a line each (the button's and the line's
## tooltip).
static func settings_words(chosen: AdventureSetup) -> String:
	var lines: Array[String] = [
		"Final battle: %s" % LIFE_NAMES[AdventurePlayer.life_rule_of(chosen.life_rule)],
		"Card rule: %s" % RULE_NAMES.get(chosen.card_rule, ""),
		"Ban list: %s%s" % [BAN_NAMES[ClassicBans.key_of(chosen.ban_list)],
			"" if chosen.card_rule == AdventurePlayer.RULE_CLASSIC else " (read only by the Classic MTG rules)"],
		"All cards offered by traders: %s" % ("on" if chosen.all_trader_cards else "off"),
		"Card hold: %s" % HOLD_NAMES[AdventurePlayer.card_hold_of(chosen.card_hold)],
		"Sieges: %s" % SIEGE_NAMES[AdventurePlayer.sieges_of(chosen.sieges)],
		"Creatures: %s" % CREATURE_NAMES[AdventurePlayer.creatures_of(chosen.creatures)],
		"Starting life: %s" % START_NAMES[AdventurePlayer.life_start_of(chosen.life_start)],
		"Ascetic hero: %s" % ("on" if chosen.ascetic else "off")]
	return "\n".join(lines)


func _show_settings_summary() -> void:
	if _settings_summary == null:
		return
	_settings_summary.text = settings_line(setup)
	var words := "%s\n\n%s" % [SETTINGS_TIP, settings_words(setup)]
	_settings_summary.tooltip_text = words
	if settings_button != null:
		settings_button.tooltip_text = words


func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	_bar = row
	row.add_theme_constant_override("separation", 16)
	leave_button = UiChrome.menu_button("Leave", Vector2(180, 46))
	leave_button.name = "Leave"
	leave_button.tooltip_text = "Back to the main menu. Your choices are kept for next time only when you embark."
	leave_button.pressed.connect(leave)
	row.add_child(leave_button)
	# THE WORLD'S SEED, beside the button that makes the world. The 1997
	# game seeded its dice from the clock as it started
	# (`srand(GetTickCount())`) and made every world from them; the field
	# comes filled in from the clock the same way, and showing the seed and
	# taking one is ours [QoL]: a number makes the same world again.
	var seed_row := HBoxContainer.new()
	_seed_row = seed_row
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_theme_constant_override("separation", 8)
	var seed_label := _label("World seed")
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_row.add_child(seed_label)
	_seed_edit = LineEdit.new()
	_seed_edit.name = "WorldSeed"
	_seed_edit.placeholder_text = "a new world"
	_seed_edit.max_length = AdventureSetup.SEED_LENGTH
	_seed_edit.custom_minimum_size = Vector2(300, 0)
	_seed_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_seed_edit.tooltip_text = "Every world is made at random from a seed, as in 1997, and the seed comes from the clock as the screen opens: the time of day, 14:35:07 making 143507. Keep it for a new world; type a number or a word to make that world again: the seed of a world you liked, or a friend's."
	_seed_edit.text_changed.connect(_on_seed_changed)
	seed_row.add_child(_seed_edit)
	row.add_child(seed_row)
	randomize_button = UiChrome.menu_button("Randomize", Vector2(180, 46))
	randomize_button.name = "Randomize"
	randomize_button.tooltip_text = "Draw every choice on this screen at random, then change any of them before you set out."
	randomize_button.pressed.connect(randomize_all)
	row.add_child(randomize_button)
	adventure_button = UiChrome.menu_button("Adventure", Vector2(220, 46), 24, 0.6)
	adventure_button.name = "Adventure"
	adventure_button.tooltip_text = "Make the world and set out."
	adventure_button.pressed.connect(embark)
	row.add_child(adventure_button)
	return row


# ------------------------------------------------------------- choices --

## One face along, wrapping; the name comes along while it is the face's.
func step_face(step: int) -> void:
	if _faces.is_empty():
		return
	var index := 0
	for i in _faces.size():
		if _faces[i]["id"] == setup.portrait:
			index = i
			break
	setup.portrait = String(_faces[wrapi(index + step, 0, _faces.size())]["id"])
	if _name_follows:
		setup.player_name = AdventureSetup.suggested_name(setup.portrait)
		_name_edit.text = setup.player_name
	_show_face()
	_show_walker()


func choose_walker(figure: String) -> void:
	setup.walker = figure
	_show_walker()
	_show_figure()


## Dress the figure's [param part] in [param key] ([HeroColors]); the 1997
## colour for [constant HeroColors.ORIGINAL] or a key not offered.
func choose_figure_color(part: String, key: String) -> void:
	if HeroColors.choice(part, key).is_empty():
		setup.figure_colors.erase(part)
	else:
		setup.figure_colors[part] = key
	_show_figure()


## Every part back in the 1997 colours (the owner, 2026-10-22: *"a default
## button that reuses the OG old game figures"*).
func reset_figure_colors() -> void:
	setup.figure_colors.clear()
	_show_figure()


## The colours of the part behind swatch [param index], in a popup by it:
## the 1997 colour first, then the part's own.
func open_figure_colors(index: int) -> void:
	var part := HeroColors.PARTS[index]
	if _figure_popup != null:
		_figure_popup.queue_free()
	_figure_popup = PopupPanel.new()
	_figure_popup.name = "FigureColorsPopup"
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.08, 0.04, 0.035, 0.97)
	face.border_color = GOLD.darkened(0.25)
	face.set_border_width_all(2)
	face.set_corner_radius_all(6)
	face.set_content_margin_all(8)
	_figure_popup.add_theme_stylebox_override("panel", face)
	var column := VBoxContainer.new()
	column.add_child(_label(HeroColors.PART_NAMES[index]))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var female := setup.walker_shown() == "female"
	var keys: Array[String] = [HeroColors.ORIGINAL]
	for row in HeroColors.choices(part):
		keys.append(String(row[0]))
	for key in keys:
		var pick := Button.new()
		pick.name = "Pick_" + key
		pick.custom_minimum_size = Vector2(34, 26)
		pick.tooltip_text = HeroColors.choice_name(part, key)
		_paint_swatch(pick, HeroColors.swatch(part, key, female), "97" if key == HeroColors.ORIGINAL else "")
		pick.pressed.connect(func() -> void:
			choose_figure_color(part, key)
			_figure_popup.hide())
		grid.add_child(pick)
	column.add_child(grid)
	_figure_popup.add_child(column)
	add_child(_figure_popup)
	var swatch := _figure_swatches[index]
	_figure_popup.popup(Rect2i(Vector2i(swatch.get_screen_position() + Vector2(0, swatch.size.y + 4)), Vector2i.ZERO))


func choose_color(key: String) -> void:
	setup.color = key
	_show_color()
	_show_playmat()


func choose_difficulty(level: int) -> void:
	setup.difficulty = level
	_show_difficulty()


func choose_pack(on: bool, id: String) -> void:
	if not packs_ready:
		return
	if on and not id in setup.packs:
		setup.packs.append(id)
	elif not on:
		setup.packs.erase(id)


func choose_all_packs(on: bool) -> void:
	if not packs_ready:
		return
	for id in _pack_checks:
		(_pack_checks[id] as CheckBox).button_pressed = on


func _on_name_changed(text: String) -> void:
	setup.player_name = text
	_name_follows = text.strip_edges() == "" \
		or text == AdventureSetup.suggested_name(setup.portrait)
	_say("")


## RANDOMIZE (the owner, 2026-10-22): every choice on the screen drawn at
## random — the face, a name ([method AdventureSetup.random_name]: a first
## name and a surname of our own, magical and sometimes funny), the figure
## on the map and its colours, the colour,
## the playmat's colour and style, the card packs, the difficulty and a new
## seed (a time of day, as the clock gives) — for the player to enjoy and
## change before setting out. The Campaign Settings are not drawn: they
## stay as the player set them. [param rng] is for tests.
func randomize_all(rng: RandomNumberGenerator = null) -> void:
	if _leaving:
		return
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if not _faces.is_empty():
		setup.portrait = String(_faces[rng.randi_range(0, _faces.size() - 1)]["id"])
	setup.player_name = AdventureSetup.random_name(rng)
	_name_follows = false
	setup.walker = AdventureSetup.WALKERS[rng.randi_range(0, AdventureSetup.WALKERS.size() - 1)]
	setup.color = String(AdventureSetup.COLORS[rng.randi_range(0, AdventureSetup.COLORS.size() - 1)]["key"])
	setup.playmat_color = String(_playmat_color.get_item_metadata(
		rng.randi_range(0, _playmat_color.item_count - 1)))
	setup.playmat_type = _playmat_type.get_item_text(rng.randi_range(0, _playmat_type.item_count - 1))
	setup.difficulty = rng.randi_range(0, AdventureSetup.DIFFICULTIES.size() - 1)
	setup.figure_colors = HeroColors.random(rng)
	var time := "%02d%02d%02d" % [rng.randi_range(0, 23), rng.randi_range(0, 59), rng.randi_range(0, 59)]
	setup.seed_text = "240000" if time == "000000" else time
	if packs_ready:
		for id in _pack_checks:
			(_pack_checks[id] as CheckBox).button_pressed = rng.randi_range(0, 1) == 1
	_show_all()
	_say("")


## Any number or word is a seed ([method AdventureSetup.parse_seed]).
func _on_seed_changed(text: String) -> void:
	setup.seed_text = text


# ---------------------------------------------------------------- show --

func _show_all() -> void:
	_name_edit.text = setup.player_name
	_seed_edit.text = setup.seed_text
	for i in _playmat_color.item_count:
		if String(_playmat_color.get_item_metadata(i)) == setup.playmat_color:
			_playmat_color.select(i)
	for i in _playmat_type.item_count:
		if _playmat_type.get_item_text(i) == setup.playmat_type:
			_playmat_type.select(i)
	_show_face()
	_show_walker()
	_show_figure()
	_show_color()
	_show_playmat()
	_show_difficulty()


func _show_face() -> void:
	var live := not _faces.is_empty()
	for arrow in _arrows:
		arrow.disabled = not live
	if not live:
		_portrait.texture = null
		_portrait_caption.text = "(no faces yet)"
		return
	_portrait.texture = PortraitLibrary.texture(setup.portrait)
	var row := AdventureSetup.hero(setup.portrait)
	_portrait_caption.text = String(row["name"]) if not row.is_empty() \
		else PortraitLibrary.title_of(setup.portrait)
	_portrait_caption.tooltip_text = _portrait_caption.text


func _show_figure() -> void:
	var female := setup.walker_shown() == "female"
	for i in _figure_swatches.size():
		var part := HeroColors.PARTS[i]
		var key := String(setup.figure_colors.get(part, HeroColors.ORIGINAL))
		_paint_swatch(_figure_swatches[i], HeroColors.swatch(part, key, female), HeroColors.PART_NAMES[i])
		_figure_swatches[i].tooltip_text = "%s on the map: %s. Click for its colors." \
			% [HeroColors.PART_NAMES[i], HeroColors.choice_name(part, key)]
	if _figure_preview != null:
		_figure_preview.show_figure(setup.walker_shown(), setup.figure_colors)


## A colour square with [param text] on it in ink or chalk, whichever reads.
func _paint_swatch(button: Button, color: Color, text: String) -> void:
	button.text = text
	var ink := Color(0.05, 0.03, 0.02) if color.get_luminance() > 0.5 else Color(0.96, 0.93, 0.86)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, ink)
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = color.lightened(0.12) if state == "hover" else color
		face.border_color = GOLD if state in ["hover", "focus"] else Color(0, 0, 0, 0.8)
		face.set_border_width_all(2)
		face.set_corner_radius_all(3)
		button.add_theme_stylebox_override(state, face)


func _show_walker() -> void:
	var shown := setup.walker_shown()
	for i in _walker_buttons.size():
		_walker_buttons[i].set_pressed_no_signal(AdventureSetup.WALKERS[i] == shown)


func _show_color() -> void:
	var row := AdventureSetup.color_row(setup.color)
	for i in _color_buttons.size():
		var chosen: bool = AdventureSetup.COLORS[i]["key"] == setup.color
		_color_buttons[i].set_pressed_no_signal(chosen)
		_color_buttons[i].modulate = Color.WHITE if chosen else Color(0.62, 0.58, 0.56)
	_color_name.text = String(row["name"])
	_color_name.add_theme_color_override("font_color", COLOR_INKS[setup.color])
	_color_flavor.text = String(row["flavor"])
	_color_gifts.text = "You begin with an amulet of %s and the world magic %s." % [
		String(row["name"]).to_lower(), String(row["world_magic"])]
	if _playmat_color != null and _playmat_color.item_count > 0:
		_playmat_color.set_item_text(0, "Your color (%s)" % String(row["name"]).to_lower())


func _show_playmat() -> void:
	for child in _playmat_preview.get_children():
		_playmat_preview.remove_child(child)
		child.queue_free()
	var style := setup.playmat_type
	if style == AdventureSetup.RANDOM_TYPE:
		style = String(DuelOptions.TERRITORY_TYPES[1]["label"])
	var ground := TerritoryGround.node(setup.playmat_color_shown(), style)
	_playmat_preview.add_child(ground)


func _show_difficulty() -> void:
	for i in _difficulty_buttons.size():
		_difficulty_buttons[i].set_pressed_no_signal(i == setup.difficulty)
	_difficulty_word.text = AdventureSetup.DIFFICULTY_WORDS[setup.difficulty]
	_difficulty_word.add_theme_color_override("font_color", DIFFICULTY_INKS[setup.difficulty])
	var start := AdventureSetup.starting_resources(setup.difficulty)
	var colors: int = start["deck_colors"]
	_difficulty_note.text = "%d gold · %d food · %d %s\nA %d-card first deck in %s." % [
		start["gold"], start["food"], start["amulets"],
		"amulet" if int(start["amulets"]) == 1 else "amulets",
		start["deck_cards"],
		"your color" if colors == 1 else ("all five colors" if colors == 5
			else "your color and %d more" % (colors - 1))]


# ------------------------------------------------------------ leaving --

## CHECK, REMEMBER, RECORD. A refusal stays on the screen, under the
## buttons and in a window; a hero who passes is remembered and their
## world's record made ([method AdventureSetup.resolve]).
func embark() -> void:
	if _leaving:
		return
	setup.player_name = _name_edit.text
	var refusal := setup.name_refusal()
	if refusal != "":
		_say(refusal)
		_name_edit.grab_focus()
		return
	_say("")
	var versions := {}
	var packs := _card_packs()
	if packs != null:
		for id in setup.packs:
			var info: Dictionary = packs.info(id)
			if not info.is_empty():
				versions[id] = String(info.get("version", ""))
	setup.remember()
	var record := setup.resolve(versions)
	print("Adventure record: %s" % JSON.stringify(record))
	embarked.emit(record)
	if DisplayServer.get_name() == "headless":
		return
	_materialize(record)


## The world is made while the hourglass runs ([method show_generating]),
## then the world screen takes over. (The original said "Shandalar
## Materializing..." over the whole screen, `@STARTUP`.)
func _materialize(record: Dictionary) -> void:
	_leaving = true
	show_generating()
	await get_tree().process_frame
	var world := await _make_world_aside(record)
	if not is_inside_tree() or world == null:
		return
	var screen := set_out(record, world)
	var tree := get_tree()
	tree.root.add_child(screen)
	tree.current_scene = screen
	queue_free()


## CONJURATION OF SHANDALAR WORLD (the owner, 2026-10-22): the bottom
## strip gives `Leave`, the seed and `Adventure` up to an [Hourglass] left of
## its middle and, right of it, the words with a row of one to five stars
## and back ([method stars]), so the player sees the work going on. The
## strip keeps its height; the choices are held still until the world
## screen takes over.
func show_generating() -> void:
	if _wait != null:
		return
	var hold := Control.new()
	hold.name = "HoldStill"
	hold.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hold.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(hold)
	var strip_height := maxf(_bar.size.y, 46.0)
	for item in [leave_button, _seed_row, randomize_button, adventure_button]:
		(item as Control).visible = false
	leave_button.disabled = true
	randomize_button.disabled = true
	adventure_button.disabled = true
	_wait = HBoxContainer.new()
	_wait.name = "Conjuration"
	_wait.alignment = BoxContainer.ALIGNMENT_CENTER
	_wait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wait.custom_minimum_size.y = strip_height
	_wait.add_theme_constant_override("separation", 18)
	# The glass stands a little taller than the strip, into the space above
	# and below it, so its gems and sand can be seen.
	var glass := Hourglass.new()
	glass.name = "Hourglass"
	glass.custom_minimum_size = Vector2(strip_height, strip_height)
	glass.reach = 1.4
	glass.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wait.add_child(glass)
	var words := _heading(CONJURATION, 26)
	words.name = "Words"
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wait.add_child(words)
	_wait_stars = _heading(stars(0), 26)
	_wait_stars.name = "Stars"
	_wait_stars.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# As wide as five stars, so the words never move as the stars count.
	var font := _wait_stars.get_theme_font("font")
	_wait_stars.custom_minimum_size.x = font.get_string_size(stars(4),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 6.0
	_wait.add_child(_wait_stars)
	_bar.add_child(_wait)
	_wait_time = 0.0
	get_viewport().gui_release_focus()


## How long each row of stars shows.
const STAR_STEP := 0.28
## The words beside the hourglass (the owner's, 2026-10-22).
const CONJURATION := "Conjuration of Shandalar World"


## The stars for [param step]: one to five and back to one, over and over.
static func stars(step: int) -> String:
	var turn := posmod(step, 8)
	return "*".repeat(turn + 1 if turn < 5 else 9 - turn)


func _process(delta: float) -> void:
	if _wait == null:
		return
	_wait_time += delta
	_wait_stars.text = stars(int(_wait_time / STAR_STEP))


## Makes [param record]'s world on a thread of its own, so the window stays
## alive while the original's generator retries: most worlds take under a
## second, about one in a hundred several (`world-builder-adventure-notes.md`,
## "Never stuck").
func _make_world_aside(record: Dictionary) -> ShandalarWorld:
	_worker = Thread.new()
	if _worker.start(func() -> ShandalarWorld: return AdventureSetup.make_world(record)) != OK:
		_worker = null
		return AdventureSetup.make_world(record)
	while _worker != null and _worker.is_alive() and is_inside_tree():
		await get_tree().process_frame
	if _worker == null:
		return null
	var made: ShandalarWorld = _worker.wait_to_finish()
	_worker = null
	return made


## A world still being made is waited for when the screen goes: the thread
## must not outlive it, nor run on while the game quits.
func _exit_tree() -> void:
	if _worker != null and _worker.is_started():
		_worker.wait_to_finish()
	_worker = null


## Told on arrival when the adventure's first save could not be written
## (campaign of 2026-10-23: it was only printed to the log).
const NOT_SAVED := "The adventure could not be saved: its folder cannot be written. Play goes on, and every later save tries again."


## THE ADVENTURE BEGINS (the owner, 2026-10-22: *"when game starts lets
## make an autosave with initial AdventurePlayer stats (by player name and
## time hash)"*): the hero ([AdventurePlayer]) made from [param record] in
## [param world], saved at once, and the world screen that shows them —
## not yet in the tree. A first save that fails is told with the arrival
## ([constant NOT_SAVED]).
func set_out(record: Dictionary, world: ShandalarWorld) -> WorldScreen:
	var adventure := AdventurePlayer.begin(record, world)
	var path := adventure.autosave()
	var screen := open_world(record, world)
	screen.player = adventure
	if path != "":
		print("Adventure saved: %s" % path)
	else:
		screen.arrival += "\n\n" + NOT_SAVED
	return screen


## The world screen for [param record], its arrival note set — not yet in
## the tree. Its world is [param world], or made here when none is given.
func open_world(record: Dictionary, world: ShandalarWorld = null) -> WorldScreen:
	var screen: WorldScreen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = record
	screen.world = world if world != null else AdventureSetup.make_world(record)
	screen.arrival = summary(record)
	return screen


## The arrival's line for an adventure of one life [ours]; "Reload allowed",
## the default, needs none.
const ONE_LIFE_SUMMARY := "One life: lose or leave the final battle, and the adventure is over."


## The record in a few sentences, for the window `Adventure` opens.
func summary(record: Dictionary) -> String:
	var hero: Dictionary = record["hero"]
	var start: Dictionary = record["start"]
	var color := AdventureSetup.color_row(String(record["color"]))
	var lines: Array[String] = []
	lines.append("%s sets out as a %s mage, at %s level: %s." % [String(hero["name"]),
		String(color["name"]).to_lower(),
		AdventureSetup.DIFFICULTIES[int(record["difficulty"])],
		AdventureSetup.difficulty_phrase(int(record["difficulty"]))])
	lines.append("%d gold, %d food, %d %s and the world magic %s." % [
		start["gold"], start["food"], start["amulets"],
		"amulet" if int(start["amulets"]) == 1 else "amulets",
		String(start["world_magic"])])
	var packs: Array = record["packs"]
	if not packs.is_empty():
		var names: Array[String] = []
		var catalogue := _card_packs()
		for pack in packs:
			var id := String(pack["id"])
			var info: Dictionary = catalogue.info(id) if catalogue != null else {}
			names.append(String(info.get("name", id)))
		lines.append("Pack worlds: %s." % ", ".join(names))
	if AdventurePlayer.life_rule_of(record.get("life_rule")) == AdventurePlayer.LIFE_ONE:
		lines.append(ONE_LIFE_SUMMARY)
	lines.append(String(HOLD_SUMMARY[AdventurePlayer.card_hold_of(record.get("card_hold"))]))
	lines.append(String(SIEGE_SUMMARY[AdventurePlayer.sieges_of(record.get("sieges"))]))
	lines.append(String(CREATURE_SUMMARY[AdventurePlayer.creatures_of(record.get("creatures"))]))
	lines.append(String(START_SUMMARY[AdventurePlayer.life_start_of(record.get("life_start"))]))
	if record.get("ascetic") is bool and bool(record.get("ascetic")):
		lines.append(ASCETIC_SUMMARY)
	if record.get("all_trader_cards") is bool and bool(record.get("all_trader_cards")):
		lines.append(TRADER_ON_LINE)
	lines.append("World seed %s." % String(record.get("seed_text", str(record["seed"]))))
	return "\n".join(lines)


## The note under the name: shown while it has something to say.
func _say(text: String) -> void:
	_note.text = text
	_note.visible = text != ""


func leave() -> void:
	if _leaving:
		return
	_leaving = true
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://game/main.tscn")


## ESCAPE IS `Leave`, as `Back` is on the battle-setup screen — after a
## window that is up, which it closes first.
func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if settings_shown():
		# Escape is the Campaign Settings' Done.
		close_settings()
		return
	if is_instance_valid(_popup) and not _popup.is_queued_for_deletion():
		UiChrome.dismiss_popup(_popup)
		_popup = null
		return
	leave()


# ------------------------------------------------------------- pieces --

func _panel(inner: Control, panel_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.09, 0.045, 0.04, 0.82)
	face.border_color = GARNET
	face.set_border_width_all(2)
	face.set_corner_radius_all(6)
	face.set_content_margin_all(12)
	face.shadow_color = Color(0, 0, 0, 0.5)
	face.shadow_size = 6
	panel.add_theme_stylebox_override("panel", face)
	panel.custom_minimum_size.x = PANEL_WIDTH
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.size_flags_vertical = Control.SIZE_FILL
	panel.add_child(inner)
	return panel


## The windows' lines' spacing: 7 since the four rules (2026-10-28; 8
## before), the Magic window's last pixels at 1280 × 800 without the skin.
const COLUMN_GAP := 7


func _column(heading: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", COLUMN_GAP)
	box.add_child(_heading(heading, 24))
	return box


## Lettering in the title face, gold on the dark field.
func _heading(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	var face := GameSkin.font("font_title")
	if face != null:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", Color8(40, 8, 6))
	label.add_theme_constant_override("outline_size", 4 if size >= 30 else 2)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


## Body lettering, light on the dark field (the menus elsewhere are dark
## on sandstone; this screen is the 1997 portrait screen's dark).
func _text(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	var face := GameSkin.font("font_body")
	if face != null:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", PARCHMENT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _label(text: String) -> Label:
	var label := _text(text, 15)
	label.add_theme_color_override("font_color", DIM)
	return label


func _toggle(text: String, size: Vector2, font_size: int, group: ButtonGroup) -> Button:
	var button := UiChrome.menu_button(text, size, font_size)
	button.toggle_mode = true
	button.button_group = group
	UiChrome.gold_when_chosen(button)
	return button


## One colour's button: its 1997 symbol from `stat_buttons`, or without
## the skin a disc of the colour with its initial, in a gold ring when
## chosen.
func _symbol_button(row: Dictionary, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.name = "Color" + String(row["name"])
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = SYMBOL_SIZE + Vector2(10, 10)
	button.tooltip_text = "%s: %s" % [String(row["name"]), String(row["flavor"])]
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "disabled"]:
		button.add_theme_stylebox_override(state, none)
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(1, 0.85, 0.5, 0.12)
	ring.border_color = GOLD
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(40)
	button.add_theme_stylebox_override("pressed", ring)
	button.add_theme_stylebox_override("hover_pressed", ring)
	button.add_theme_stylebox_override("focus", OriginalDialog.focus_ring())
	var sheet := GameSkin.texture("stat_buttons")
	var picture: Control
	if sheet != null:
		var symbol := TextureRect.new()
		symbol.texture = ImageTexture.create_from_image(GameSkin.cut(sheet,
			Rect2i(int(row["symbol"]) * SYMBOL_CELL, 0, SYMBOL_CELL, SYMBOL_CELL)))
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture = symbol
	else:
		var disc := Panel.new()
		var fill := StyleBoxFlat.new()
		fill.bg_color = COLOR_INKS[String(row["key"])].darkened(0.25)
		fill.set_corner_radius_all(32)
		disc.add_theme_stylebox_override("panel", fill)
		var letter := Label.new()
		letter.text = String(row["name"]).left(1) if row["key"] != "blue" else "U"
		letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_font_size_override("font_size", 28)
		letter.add_theme_color_override("font_color", Color8(20, 14, 12))
		disc.add_child(letter)
		picture = disc
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	button.add_child(picture)
	button.pressed.connect(choose_color.bind(String(row["key"])))
	return button
