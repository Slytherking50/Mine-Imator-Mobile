/// app_update_folder_tree_export()
/// @desc Polls for android_pick_folder_tree()'s result (2026-09-16, action_project_export_external.gml/
/// action_project_import_external.gml - both funnel through the same picker, so both are polled
/// here rather than in 2 separate functions that could otherwise race on the same result).
/// Called every frame from app_event_step.gml, same shape as the other app_update_* calls there -
/// android_export_pending/android_import_pending keep this a no-op on every frame nothing is
/// pending, and always false on non-Android.

function app_update_folder_tree_export()
{
	if (!android_folder_tree_pick_done() || (!android_export_pending && !android_import_pending))
		return 0

	var was_export = android_export_pending;
	android_export_pending = false
	android_import_pending = false

	var tree_uri = android_folder_tree_result();
	if (tree_uri = "")
		return 0 // Cancelled - silent, same as backing out of any other file picker

	if (was_export)
	{
		if (project_export_external_do(tree_uri))
			toast_new(e_toast.POSITIVE, text_get("toastexportexternalsuccess"))
		else
			toast_new(e_toast.NEGATIVE, text_get("toastexportexternalfail"))
	}
	else
	{
		var project_path = project_import_external_do(tree_uri);
		if (project_path != "")
		{
			toast_new(e_toast.POSITIVE, text_get("toastimportexternalsuccess"))
			project_load(project_path)
			window_state = ""
		}
		else
			toast_new(e_toast.INFO, text_get("toastimportexternalnoproject"))
	}
}
