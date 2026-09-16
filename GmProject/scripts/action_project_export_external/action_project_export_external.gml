/// action_project_export_external()
/// @desc Android-only "Exportar a carpeta externa..." (2026-09-16, follow-up to B37). Opens the
/// system folder picker; app_update_folder_tree_export() (app_event_step.gml) polls for the
/// result and does the actual copy once it resolves.

function action_project_export_external()
{
	android_export_pending = true
	android_pick_folder_tree()
}
