/// action_project_import_external()
/// @desc Android-only "Importar desde carpeta externa..." (2026-09-16, follow-up to B39/
/// KNOWN_ISSUES.md - the import direction). Opens the system folder picker;
/// app_update_folder_tree_export() (app_event_step.gml) polls for the result and does the
/// actual copy once it resolves.

function action_project_import_external()
{
	android_import_pending = true
	android_pick_folder_tree()
}
