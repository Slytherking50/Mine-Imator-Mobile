#include "Generated/Scripts.hpp"

#if defined(Q_OS_ANDROID)
#include <private/qjni_p.h>
#include <private/qjnihelpers_p.h>
#endif

namespace CppProject
{
#if defined(Q_OS_ANDROID)
	// Same JniExceptionCleaner as FileFunc.cpp/Buffer.cpp (2026-09-15 SAF work) - duplicated
	// per translation unit rather than shared, same reasoning as those two.
	class JniExceptionCleaner
	{
	public:
		JniExceptionCleaner() { clearException(); }
		~JniExceptionCleaner() { clearException(); }

		bool clean() { return clearException(); }
	private:
		bool clearException()
		{
			QJNIEnvironmentPrivate env;
			if (env->ExceptionCheck())
			{
				env->ExceptionDescribe();
				env->ExceptionClear();
				return true;
			}
			return false;
		}
	};
#endif

	// Auto-update (2026-09-15, user request) - hands a downloaded APK (app_event_http.gml's
	// http_download_update branch, saved to user_directory_get() + "updates/update.apk") to
	// Android's package installer. Needs a content:// URI, not the raw file:// path -
	// FileUriExposedException on API 24+ - via androidx.core.content.FileProvider
	// (AndroidManifest.xml's <provider>, res/xml/file_paths.xml, build.gradle's new
	// androidx.core:core dependency). The authority string is built from the app's own real
	// package name at runtime (getPackageName() + ".fileprovider") instead of hardcoding
	// org.internal.testbuild, which AndroidManifest.xml's own comment already flags as a
	// placeholder to be replaced before real distribution - this way that rename doesn't also
	// require touching this function.
	BoolType android_install_apk(StringType localPath)
	{
#if defined(Q_OS_ANDROID)
		JniExceptionCleaner exceptionCleaner;

		QJNIObjectPrivate context = QJNIObjectPrivate(QtAndroidPrivate::context());

		QJNIObjectPrivate packageName = context.callObjectMethod("getPackageName", "()Ljava/lang/String;");
		if (!packageName.isValid())
		{
			DEBUG("android_install_apk: could not get package name");
			return false;
		}

		QString authority = packageName.toString() + ".fileprovider";

		QJNIObjectPrivate jfile(QJNIObjectPrivate::fromString(localPath.QStr()));
		QJNIObjectPrivate file("java/io/File", "(Ljava/lang/String;)V", jfile.object());
		if (!file.isValid())
		{
			DEBUG("android_install_apk: java.io.File construction failed for " + localPath.QStr());
			return false;
		}

		QJNIObjectPrivate uri = QJNIObjectPrivate::callStaticObjectMethod(
			"androidx/core/content/FileProvider", "getUriForFile",
			"(Landroid/content/Context;Ljava/lang/String;Ljava/io/File;)Landroid/net/Uri;",
			context.object(), QJNIObjectPrivate::fromString(authority).object(), file.object());

		if (exceptionCleaner.clean())
		{
			// Most likely IllegalArgumentException: localPath isn't under any root declared in
			// res/xml/file_paths.xml (this is exactly what happened 2026-09-16, first real
			// end-to-end test - fixed there, kept this log for any future path mismatch).
			DEBUG("android_install_apk: FileProvider.getUriForFile threw for " + localPath.QStr() + " (authority " + authority + ") - check res/xml/file_paths.xml covers this path");
			return false;
		}
		if (!uri.isValid())
		{
			DEBUG("android_install_apk: FileProvider.getUriForFile returned an invalid Uri for " + localPath.QStr());
			return false;
		}

		QJNIObjectPrivate intent("android/content/Intent");
		intent.callObjectMethod("setAction", "(Ljava/lang/String;)Landroid/content/Intent;",
			QJNIObjectPrivate::fromString("android.intent.action.VIEW").object());

		QJNIObjectPrivate mimeType = QJNIObjectPrivate::fromString("application/vnd.android.package-archive");
		intent.callObjectMethod("setDataAndType", "(Landroid/net/Uri;Ljava/lang/String;)Landroid/content/Intent;",
			uri.object(), mimeType.object());

		// Intent.FLAG_GRANT_READ_URI_PERMISSION (0x1) | Intent.FLAG_ACTIVITY_NEW_TASK
		// (0x10000000) - stable public SDK constants, used as literals rather than looked up
		// via JNI static field access (both approaches are equally "hardcoded", this one is
		// just less code for two values that are part of Android's own frozen public API).
		intent.callObjectMethod("addFlags", "(I)Landroid/content/Intent;", jint(0x1 | 0x10000000));

		if (exceptionCleaner.clean())
		{
			DEBUG("android_install_apk: building the install Intent threw");
			return false;
		}

		context.callMethod<void>("startActivity", "(Landroid/content/Intent;)V", intent.object());

		if (exceptionCleaner.clean())
		{
			// Most likely ActivityNotFoundException (no package installer handles this MIME
			// type on this device/ROM) - distinct from the FileProvider failure above.
			DEBUG("android_install_apk: startActivity(install intent) threw - no installer available?");
			return false;
		}

		DEBUG("android_install_apk: launched installer for " + localPath.QStr());
		return true;
#else
		return false;
#endif
	}

	// "Compartir registro" (2026-09-16, user request) - a friend testing the app on their own
	// device has no way to get log.txt out otherwise: Android's scoped storage makes the app's
	// internal folder invisible to any file manager/MTP browsing, by OS design, no matter what
	// permission is granted - there's no "enable" switch for that, sharing the file directly
	// (through whatever app the user picks - email, a messaging app, etc.) is the real
	// equivalent of desktop's F11/open_url(log_file). Same FileProvider mechanism as
	// android_install_apk above, ACTION_SEND instead of ACTION_VIEW - kept as its own function
	// rather than a generic "share any path" helper since only log.txt is declared in
	// res/xml/file_paths.xml (deliberately, not the whole Mine-imator/ folder - see that file's
	// comment) and every other call site continues through lib_file_copy/WriteBytesToAndroidContentUri
	// for destinations the USER already picked via a SAF dialog, a different situation.
	BoolType android_share_log()
	{
#if defined(Q_OS_ANDROID)
		JniExceptionCleaner exceptionCleaner;

		QJNIObjectPrivate context = QJNIObjectPrivate(QtAndroidPrivate::context());

		QJNIObjectPrivate packageName = context.callObjectMethod("getPackageName", "()Ljava/lang/String;");
		if (!packageName.isValid())
		{
			DEBUG("android_share_log: could not get package name");
			return false;
		}

		QString authority = packageName.toString() + ".fileprovider";

		QJNIObjectPrivate jfile(QJNIObjectPrivate::fromString(StringType(log_file).QStr()));
		QJNIObjectPrivate file("java/io/File", "(Ljava/lang/String;)V", jfile.object());
		if (!file.isValid())
		{
			DEBUG("android_share_log: java.io.File construction failed for " + StringType(log_file).QStr());
			return false;
		}

		QJNIObjectPrivate uri = QJNIObjectPrivate::callStaticObjectMethod(
			"androidx/core/content/FileProvider", "getUriForFile",
			"(Landroid/content/Context;Ljava/lang/String;Ljava/io/File;)Landroid/net/Uri;",
			context.object(), QJNIObjectPrivate::fromString(authority).object(), file.object());

		if (exceptionCleaner.clean())
		{
			// Most likely IllegalArgumentException - log.txt not existing yet (nothing has ever
			// been logged) isn't the cause, FileProvider only cares about the declared root, not
			// whether the file exists - check res/xml/file_paths.xml's "log" entry matches.
			DEBUG("android_share_log: FileProvider.getUriForFile threw (authority " + authority + ") - check res/xml/file_paths.xml covers log.txt");
			return false;
		}
		if (!uri.isValid())
		{
			DEBUG("android_share_log: FileProvider.getUriForFile returned an invalid Uri");
			return false;
		}

		QJNIObjectPrivate sendIntent("android/content/Intent");
		sendIntent.callObjectMethod("setAction", "(Ljava/lang/String;)Landroid/content/Intent;",
			QJNIObjectPrivate::fromString("android.intent.action.SEND").object());

		sendIntent.callObjectMethod("setType", "(Ljava/lang/String;)Landroid/content/Intent;",
			QJNIObjectPrivate::fromString("text/plain").object());

		sendIntent.callObjectMethod("putExtra",
			"(Ljava/lang/String;Landroid/os/Parcelable;)Landroid/content/Intent;",
			QJNIObjectPrivate::fromString("android.intent.extra.STREAM").object(), uri.object());

		// FLAG_GRANT_READ_URI_PERMISSION (0x1) - without this the app the user picks (Gmail,
		// WhatsApp, etc.) can't actually open the content:// URI, same reasoning as
		// android_install_apk's install Intent above.
		sendIntent.callMethod<void>("addFlags", "(I)V", jint(0x1));

		if (exceptionCleaner.clean())
		{
			DEBUG("android_share_log: building the share Intent threw");
			return false;
		}

		// createChooser() so this always shows a picker (which app to share through) instead of
		// silently going to whatever the device's default happens to be, or nothing at all if
		// there isn't one - the point of this feature is showing the log to a specific person.
		QJNIObjectPrivate chooserTitle = QJNIObjectPrivate::fromString(QStringLiteral("Mine-imator log.txt"));
		QJNIObjectPrivate chooser = QJNIObjectPrivate::callStaticObjectMethod(
			"android/content/Intent", "createChooser",
			"(Landroid/content/Intent;Ljava/lang/CharSequence;)Landroid/content/Intent;",
			sendIntent.object(), chooserTitle.object());

		if (exceptionCleaner.clean() || !chooser.isValid())
		{
			DEBUG("android_share_log: Intent.createChooser failed");
			return false;
		}

		context.callMethod<void>("startActivity", "(Landroid/content/Intent;)V", chooser.object());

		if (exceptionCleaner.clean())
		{
			DEBUG("android_share_log: startActivity(chooser) threw");
			return false;
		}

		DEBUG("android_share_log: launched share chooser for log.txt");
		return true;
#else
		return false;
#endif
	}
}
