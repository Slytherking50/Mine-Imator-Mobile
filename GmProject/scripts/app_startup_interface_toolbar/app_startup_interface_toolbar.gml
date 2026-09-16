/// app_startup_interface_toolbar()

function app_startup_interface_toolbar()
{
	// toolbar_size is derived from ui_large_height every frame in app_update_interface() -
	// it used to be a flat 28 set once here, disconnected from that scaling (CLAUDE.md
	// §6.2). Not initialized here anymore; app_update_interface() runs before first draw,
	// same as ui_large_height/ui_small_height themselves.
	toolbar_menu_active = false
}
