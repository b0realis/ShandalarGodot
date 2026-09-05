class_name DamageMarker
extends Button
## THE DAMAGE MARKER — one waiting [DamagePacket], drawn as the yellow
## card the 1997 game put on the table and clicked exactly like a card.
##
## `Duel.hlp` names it three times, in three different topics, and every
## one of them is a list of the things a target can BE:
##  * **Using Land** — *"If the effect is a targeted one (damage
##    prevention, for example, which targets damage), you also need to
##    choose a target. When you're prompted, click on any valid target —
##    a card, A DAMAGE MARKER, or whatever."*
##  * **Spells** — *"When you're prompted, click on any valid target card,
##    DAMAGE MARKER, or whatever."*
##  * **Effects** — *"click on any valid target — a card, A DAMAGE MARKER,
##    or whatever."*
##
## The manual says what it looks like (p.119): *"a damage marker — a
## yellow 'card' on or near the target of that damage"*, and `Duel.hlp`'s
## **Territory** topic names the family it belongs to — *"those effect
## cards (the temporary yellow cards that pop up all the time)"*. The
## original's own prompt for clicking one is `@CIRCLE_OF_PROTECTION`
## (`Program/prompts.txt:185`): **`Select damage card.`** It is a CARD, in
## the original's own vocabulary, three sources deep.
##
## Deliberately NOT a [MiniCard]: there is no [CardInstance] behind it, so
## eight of the ten `@CUECARD_SMALLCARD` states — summoning sickness,
## dying, will untap, not controlled by owner — are questions you cannot
## ask of it. The two that ARE its own are below.
## But it IS [constant MiniCard.SIZE] and is never rescaled —
## the one-card-size rule is about what the table looks like, not about
## which class drew it, and a marker that sat between two cards at some
## other size would break the rule in the only way the rule is about.
##
## WHAT IT MUST SHOW, and why: choosing BETWEEN packets is the whole
## decision the 1997 window exists for, so the marker leads with the two
## things that tell two packets apart — the SOURCE (on the title bar,
## where a card carries its name) and the AMOUNT (the numeral over the
## art, where a creature carries its power). The victim is the third line,
## because the marker is already drawn next to it.

## The waiting packet this marker stands for. Read-only here: the widget
## never mutates engine state, exactly as [MiniCard] never mutates its
## instance.
var packet: DamagePacket = null

## OPTIONAL game reference, for the victim's name (a card ref is an id
## until somebody looks it up). Null in a unit test that hands the widget
## a bare packet; the victim line simply reads the id instead.
var game: MtgGame = null

## `@CUECARD_SMALLCARD` VERBATIM (`UIStrings.txt:732`, latin-1 — GNU grep
## prints nothing without `-a`), the two entries that are about DAMAGE.
##
## `Damage: %d` is entry 3 and [MiniCard] already draws it for the damage
## MARKED on a creature. `Damage to player` is entry 1, which
## `docs/duel-todo.md` §2.10 wrote off as *"the life register's state
## (§6.5)"* — and that cannot be right: `@CUECARD_LIFE` (`:678`) declares
## eight entries and this is not one of them. It is in the SMALL CARD's
## table because the object it describes is a small card: a damage marker
## whose victim is a player, which is the one small card on the table that
## can be about damage to a player at all.
const CUE_CARD := "Damage: %d"
const CUE_PLAYER := "Damage to player"

## Manual p.119's *"yellow 'card'"*. The hue is [MiniCard]'s own OPTIONAL
## yellow rather than a second one — the marker is a thing you MAY act on,
## which is what that colour means everywhere else on this table.
const MARKER_YELLOW := Color(0.95, 0.80, 0.25)
## The card body under the title bar: the same yellow, taken well down so
## the black numeral over it reads at a glance across the table.
const MARKER_GROUND := Color(0.42, 0.34, 0.09)

## Corner radius and content margin, matching [MiniCard]'s unskinned frame
## so a marker sitting beside a card is the same shape.
const CORNER := 6
const MARGIN := 4

var _highlight: int = MiniCard.Highlight.OPTIONAL
var _target_state: int = -1
var _source_label: Label = null
var _band: ColorRect = null
var _amount_label: Label = null
var _victim_label: Label = null
var _dagger: TextureRect = null
var _stamp: TextureRect = null


func _init(p_packet: DamagePacket = null, p_game: MtgGame = null) -> void:
	packet = p_packet
	game = p_game
	custom_minimum_size = MiniCard.SIZE
	size = MiniCard.SIZE
	# SHRINK_CENTER on both axes for the same reason [MiniCard] carries it:
	# a FlowContainer stretches a SIZE_FILL child to its line height, and
	# this widget must be one card and no more wherever it is parented.
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text = ""
	clip_text = false
	focus_mode = Control.FOCUS_ALL
	_apply_style()
	_build_face()
	refresh()


func _build_face() -> void:
	# TITLE BAR: the SOURCE's name, where a card carries its own. This is
	# the line that makes two markers tell apart, so it is the first thing
	# built and the only one that gets the card's own name font size.
	_band = ColorRect.new()
	_band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_band.offset_left = 3
	_band.offset_right = -3
	_band.offset_top = 2
	_band.offset_bottom = 18
	_band.color = MARKER_YELLOW
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	_source_label = Label.new()
	_source_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_source_label.offset_left = 6
	_source_label.offset_right = -4
	_source_label.offset_top = 2
	_source_label.offset_bottom = 18
	_source_label.add_theme_font_size_override("font_size",
		MiniCard.NAME_FONT_SIZE)
	# Dark ink on a light bar — [MiniCard]'s own contrast rule for a pale
	# title band (see MiniCard._tint_face).
	_source_label.add_theme_color_override("font_color", Color(0.10, 0.08, 0.04))
	_source_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Never shrink the font: a long source name is TRIMMED, exactly as a
	# long card name is.
	_source_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_source_label)

	# THE 1997 DAGGER (`Damage.pic`), the mark the original already draws on
	# a wounded creature — the same art, on the object the damage IS. It
	# only appears when the player has imported the original's set; without
	# it the numeral stands alone, which is what the fallback skin does
	# everywhere else.
	_dagger = TextureRect.new()
	_dagger.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_dagger.offset_left = 10
	_dagger.offset_top = -14
	_dagger.offset_right = 38
	_dagger.offset_bottom = 14
	_dagger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dagger.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dagger.texture = MiniCard.damage_marker_texture()
	_dagger.visible = _dagger.texture != null
	_dagger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dagger)

	# THE AMOUNT, big, where a creature wears its power — the second half
	# of "which packet is this?".
	_amount_label = Label.new()
	_amount_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_amount_label.offset_top = 18
	_amount_label.offset_bottom = -20
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_amount_label.add_theme_font_size_override("font_size", 34)
	_amount_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.55))
	_amount_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_amount_label.add_theme_constant_override("shadow_offset_x", 1)
	_amount_label.add_theme_constant_override("shadow_offset_y", 1)
	_amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_amount_label)

	# WHO IT IS AIMED AT, on the bottom edge. The marker already sits next
	# to its victim (manual p.119: *"on or near the target of that
	# damage"*), so this is a confirmation rather than the news — which is
	# why it is the small line.
	_victim_label = Label.new()
	_victim_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_victim_label.offset_left = 5
	_victim_label.offset_right = -5
	_victim_label.offset_top = -20
	_victim_label.offset_bottom = -3
	_victim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victim_label.add_theme_font_size_override("font_size", 10)
	_victim_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.72))
	_victim_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_victim_label.add_theme_constant_override("shadow_offset_x", 1)
	_victim_label.add_theme_constant_override("shadow_offset_y", 1)
	_victim_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_victim_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_victim_label)

	# THE REFUSAL STAMP — `CantTarget.pic`, the orange circle-slash, and
	# the same one a card wears for the same reason
	# ([constant MiniCard.State.CANT_TARGET], `@CUECARD_SMALLCARD` entry
	# 6). It earns its place here rather than being a colour change on the
	# frame because the frame has nothing left to say: the manual gives
	# OPTIONAL and TARGET_LEGAL one yellow between them (p.115/p.120/p.128),
	# so "this is a legal choice" is drawn by the ABSENCE of the slash on a
	# table where the illegal ones carry it — which is exactly how the
	# original marks the same moment.
	_stamp = TextureRect.new()
	_stamp.set_anchors_preset(Control.PRESET_CENTER)
	_stamp.offset_left = -MiniCard.STAMP / 2.0
	_stamp.offset_top = -MiniCard.STAMP / 2.0
	_stamp.offset_right = MiniCard.STAMP / 2.0
	_stamp.offset_bottom = MiniCard.STAMP / 2.0
	_stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stamp.tooltip_text = MiniCard.STATE_CUE[MiniCard.State.CANT_TARGET]
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.visible = false
	add_child(_stamp)


## Re-derive the whole face from the packet. Cheap; called whenever the
## layer rebuilds, which is every board refresh a window is open for.
func refresh() -> void:
	if packet == null:
		_source_label.text = ""
		_amount_label.text = ""
		_victim_label.text = ""
		tooltip_text = ""
		return
	_source_label.text = source_name()
	# REMAINING, not the printed amount: a Circle that has already answered
	# part of this packet leaves the rest on the table, and "you may use the
	# Circle on the same damage more than once" means the player has to be
	# able to see how much is left to answer.
	_amount_label.text = str(packet.remaining())
	_victim_label.text = victim_name()
	var refused := _target_state == MiniCard.State.CANT_TARGET
	if refused and _stamp.texture == null:
		_stamp.texture = MiniCard.masked_sprite(
			MiniCard.STATE_SPRITE[MiniCard.State.CANT_TARGET])
	_stamp.visible = refused and _stamp.texture != null
	# The dagger and the numeral stand aside for the refusal stamp, which
	# shares their spot — the small card's own rule for its centre stamps.
	_dagger.visible = not refused and _dagger.texture != null
	# NAME first, then the 1997 cue cards for whatever it is wearing —
	# the tooltip [MiniCard] builds, for the same reason: the overlays are
	# mouse-transparent, so this is the only place the player reads them.
	# `Show cue cards` (§6.4) governs the cue half and nothing else.
	tooltip_text = "%d damage from %s" % [packet.remaining(), source_name()]
	if DuelOptions.toggle("ShowCueCards"):
		tooltip_text += "\n" + cue_card()
		if refused:
			tooltip_text += "\n" + MiniCard.STATE_CUE[MiniCard.State.CANT_TARGET]


## The dealer's card name, or `?` for a sourceless packet — the same word
## [method DamagePacket._to_string] uses for one.
func source_name() -> String:
	if packet == null or packet.source == null:
		return "?"
	return packet.source.data.card_name


## Who the damage is aimed at, in the words the player is already reading
## elsewhere on the table: a seat's own `player_name`, or a card's name.
func victim_name() -> String:
	if packet == null or packet.target == null:
		return ""
	if packet.target.is_player:
		if game != null and packet.target.player_id >= 0 \
				and packet.target.player_id < game.players.size():
			return game.players[packet.target.player_id].player_name
		return "player %d" % packet.target.player_id
	if game != null:
		var inst := game.find_instance(packet.target.instance_id)
		if inst != null:
			return inst.data.card_name
	return "#%d" % packet.target.instance_id


## The 1997 cue card for this marker — [constant CUE_PLAYER] when the
## victim is a player, [constant CUE_CARD] filled with what is still
## coming otherwise. See the constants for why those two strings are the
## marker's and not the life register's.
func cue_card() -> String:
	if packet == null:
		return ""
	if packet.target != null and packet.target.is_player:
		return CUE_PLAYER
	return CUE_CARD % packet.remaining()


## Frame state, from [enum MiniCard.Highlight] — the SAME vocabulary and
## the same colours the cards round it use, so "this is a legal target"
## and "you have chosen this" read identically whether the player is
## looking at a card or at damage.
func set_highlight(mode: int) -> void:
	if _highlight == mode:
		return
	_highlight = mode
	_apply_style()


func highlight() -> int:
	return _highlight


## The duel screen's own targeting news, pushed down exactly as
## [method MiniCard.set_target_state] takes it:
## [constant MiniCard.State.CANT_TARGET] when the open slot refuses this
## packet, or -1. A question about the PROMPT IN PROGRESS, which lives in
## the screen — the marker cannot derive it.
func set_target_state(state: int) -> void:
	if _target_state == state:
		return
	_target_state = state
	refresh()


func target_state() -> int:
	return _target_state


func _apply_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = MARKER_GROUND
	box.border_color = MiniCard.HIGHLIGHT_COLORS[_highlight]
	box.set_border_width_all(MiniCard.HIGHLIGHT_WIDTH[_highlight])
	box.set_corner_radius_all(CORNER)
	box.set_content_margin_all(MARGIN)
	var hover: StyleBoxFlat = box.duplicate()
	hover.bg_color = MARKER_GROUND.lightened(0.18)
	for state in ["normal", "focus"]:
		add_theme_stylebox_override(state, box)
	for state in ["hover", "pressed"]:
		add_theme_stylebox_override(state, hover)
