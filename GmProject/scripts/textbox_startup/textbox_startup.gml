/// textbox_startup()
/// @desc Creates variables for using textboxes.

function textbox_startup()
{
	textbox_lastfocus = -1
	textbox_click = false
	textbox_marker = 0
	textbox_mouseover = -1
	textbox_select_startline = 0
	textbox_select_startpos = 0
	textbox_select_endline = 0
	textbox_select_endpos = 0
	textbox_select_mouseline = 0
	textbox_select_mousepos = 0
	textbox_select_clickline = 0
	textbox_select_clickpos = 0
	textbox_isediting = false
	textbox_isediting_respond = false
	// textbox_isediting_prev: edge-detector for app_update_keyboard.gml to know exactly the
	// frame textbox_isediting flips, so it can call keyboard_virtual_show()/_hide() (Android
	// virtual keyboard, KNOWN_ISSUES.md B20) only once per transition, not every frame.
	textbox_isediting_prev = false
	textbox_input = ""
	textbox_jump = false
	textbox_jumpto = -1
	textbox_list = ds_list_create()
}
