/// touch_multiselect_active()
/// @desc Android-only (B38, 2026-09-16): whether the multi-select toggle (view_toolbar_draw_touch.gml)
/// is on. Wherever a selection call site checks keyboard_check(vk_shift)/vk_control to mean "add
/// this to the current selection instead of replacing it" or "toggle this one off", OR this in -
/// it stands in for the modifier key touch has no way to hold down. Deliberately NOT wired into
/// every keyboard_check(vk_control) in the project - some (view_click.gml's nested-child pick,
/// the area-select scripts' invert-selection Ctrl, tab_timeline.gml's snap/wheel-focus Ctrl) mean
/// something unrelated to multi-select, and OR'ing this in there would misfire. See KNOWN_ISSUES.md
/// B38 for the full site-by-site classification.

function touch_multiselect_active()
{
	return (platform_get() == e_platform.ANDROID && touch_multiselect)
}
