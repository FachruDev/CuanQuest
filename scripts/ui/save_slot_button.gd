extends ChunkyButton
## Kartu slot simpanan manual di panel "Muat Game" layar judul.

const BADGE_EMPTY_COLOR := Color("#b5a089")


func setup(index: int, slot: String) -> void:
	var meta := SaveManager.slot_meta(slot)
	%Number.text = str(index + 1)
	%SlotName.text = tr("SAVE_SLOT") % (index + 1)
	disabled = meta.is_empty()
	%Money.visible = not disabled
	%Chevron.visible = not disabled
	if disabled:
		%Badge.theme_type_variation = &"BadgeEmptyPanel"
		%Number.add_theme_color_override("font_color", BADGE_EMPTY_COLOR)
		%Title.text = tr("SAVE_EMPTY")
		%Detail.text = tr("TITLE_LOAD_EMPTY_HINT")
		for label: Label in [%SlotName, %Title, %Detail]:
			label.add_theme_color_override("font_color", Palette.DISABLED_TEXT)
		return
	%Title.text = "%s · %s" % [meta["player_name"], Fmt.game_date(int(meta["month"]))]
	%Detail.text = tr("TITLE_SAVED_AT") % SaveManager.saved_at_text(meta)
	var net_worth: float = meta["net_worth"]
	%Money.text = Fmt.rupiah_short(net_worth)
	%Money.add_theme_color_override("font_color", Palette.GAIN if net_worth >= 0 else Palette.LOSS)
