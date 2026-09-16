package org.internal.testbuild;

import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver;
import android.view.Window;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import org.qtproject.qt5.android.QtEditText;
import org.qtproject.qt5.android.bindings.QtActivity;

// Thin subclass of Qt's own QtActivity, only to set FLAG_KEEP_SCREEN_ON - Qt 5.15AndroidExtras
// (QtAndroid/QAndroidJniObject) isn't built into this project's Qt-Android install (rebuilding
// Qt from source takes hours, B16, disproportionate for one window flag), so this is done at
// the Java layer instead of via JNI from C++. package matches AndroidManifest.xml's placeholder
// package (org.internal.testbuild, CLAUDE.md §9.3/§9.5) - move alongside it when that's renamed.
public class MineImatorActivity extends QtActivity
{
    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        // Black strip on one landscape edge, reported by beta testers (2026-09-11) and
        // confirmed for real via `adb shell dumpsys window displays` on the reference device
        // (220333QL, Android 13/API 33): it has a real display cutout - a 49px front-camera
        // notch centered on the physical TOP edge in portrait. The app is locked to
        // sensorLandscape (AndroidManifest.xml), so that portrait-top cutout rotates to a
        // LEFT/RIGHT edge in landscape. By default Android reserves that cutout's area from
        // the window's content (window_get_width()/height(), WindowFunc.cpp, faithfully
        // report Qt's own AppWin->width()/height(), which is genuinely smaller than the
        // physical screen here) - not a bug in how those are read, the window itself is
        // really that size. LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS (API 30+, this device is 33)
        // tells Android the app wants to draw INTO the cutout area on every edge, portrait or
        // landscape, instead of reserving it - the standard, documented mechanism for this,
        // unrelated to the earlier reverted attempt to fix a similar-looking gap by forcing
        // the QMainWindow's own setGeometry() (CLAUDE.md §17, 2026-09-09 - MIUI reinterpreted
        // that as a floating-window request; this touches only a window attribute Android
        // itself defines for exactly this purpose, not the window's geometry).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
        {
            Window window = getWindow();
            WindowManager.LayoutParams attrs = window.getAttributes();
            attrs.layoutInDisplayCutoutMode = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                ? WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                : WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            window.setAttributes(attrs);
        }

        // Gboard (and most IMEs) switch to their own fullscreen "extract" editing UI - a
        // solid-colored overlay covering nearly the whole screen, with just a Done button and
        // an empty preview line, squeezing the real app content into a thin strip - whenever
        // Configuration.orientation is landscape, UNLESS the focused field's EditorInfo carries
        // EditorInfo.IME_FLAG_NO_FULLSCREEN (confirmed real via `javap` against this SDK's own
        // android.jar, not assumed). The app is locked to sensorLandscape (AndroidManifest.xml)
        // for the whole editor, so every text field hits this - confirmed live on the reference
        // device via `adb shell screencap` while the keyboard was open (2026-09-11), reported
        // by the user as the keyboard "muy pegado"/off-center. Qt's own Android Java layer
        // (QtActivityDelegate.setKeyboardVisibility(), confirmed by reading its real 5.15.19
        // source: qtbase/src/android/jar/src/org/qtproject/qt5/android/QtActivityDelegate.java)
        // computes imeOptions itself from Qt::InputMethodHints and never ORs this flag in - and
        // exposes no hint that would make it. QtEditText (same source tree) is a public class
        // with a public setImeOptions(int), so this reaches in from here instead of patching
        // Qt's own shipped Java sources for one flag. Qt (re)calls its own setImeOptions() every
        // time the keyboard's shown/hidden, which would clobber a one-time call here - a
        // persistent OnGlobalLayoutListener keeps reapplying it on every layout pass instead,
        // which fires well before the IME actually connects. KeyChecker (AppWindow.cpp) is the
        // single shared text-capture widget for every GML field and never sets any
        // Qt::InputMethodHint that would change Qt's own default (confirmed by reading
        // AppWindow.cpp - only Qt::ImhNone), so ORing this onto Qt's IME_ACTION_DONE default
        // (QtActivityDelegate.java's own base value before any hint-specific branch) can't
        // clobber a more specific choice made elsewhere - there isn't one.
        getWindow().getDecorView().getViewTreeObserver().addOnGlobalLayoutListener(() ->
        {
            QtEditText editText = findQtEditText(getWindow().getDecorView());
            if (editText != null)
                editText.setImeOptions(EditorInfo.IME_ACTION_DONE | EditorInfo.IME_FLAG_NO_FULLSCREEN);
        });
    }

    // External project folder export (2026-09-16, user request) - ACTION_OPEN_DOCUMENT_TREE is
    // the only way to get a real, persistent, user-picked directory outside the app's own
    // sandbox under scoped storage (minSdkVersion=29, CLAUDE.md §7.1.1) - unlike the single-file
    // pickers android_install_apk/get_open_filename_ext already use (startActivity, no result
    // needed), this one requires startActivityForResult + onActivityResult, both new to this
    // project. requestCode is an arbitrary app-chosen int (Android convention), only used to
    // tell "our" result apart from any other activity result in the same Activity - there's
    // only ever this one pending request in the app, so a single fixed value is enough.
    private static final int REQUEST_CODE_PICK_FOLDER_TREE = 4201;

    // Implemented in FileFunc.cpp (JNIEXPORT). Name-mangled to this exact package/class -
    // must move together if org.internal.testbuild is ever renamed (CLAUDE.md §9.3/§9.5).
    public native void nativeFolderTreePicked(String treeUriString);

    public void pickFolderTree()
    {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        startActivityForResult(intent, REQUEST_CODE_PICK_FOLDER_TREE);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data)
    {
        super.onActivityResult(requestCode, resultCode, data);

        if (requestCode != REQUEST_CODE_PICK_FOLDER_TREE)
            return;

        if (resultCode != RESULT_OK || data == null || data.getData() == null)
        {
            nativeFolderTreePicked(""); // Cancelled - empty string is the "nothing picked" sentinel
            return;
        }

        Uri treeUri = data.getData();

        // Without this the permission only lasts until the app process dies - the whole point
        // of picking an external folder once is to keep writing to it across app restarts.
        getContentResolver().takePersistableUriPermission(treeUri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);

        nativeFolderTreePicked(treeUri.toString());
    }

    private static QtEditText findQtEditText(View view)
    {
        if (view instanceof QtEditText)
            return (QtEditText) view;

        if (view instanceof ViewGroup)
        {
            ViewGroup group = (ViewGroup) view;
            for (int i = 0; i < group.getChildCount(); i++)
            {
                QtEditText found = findQtEditText(group.getChildAt(i));
                if (found != null)
                    return found;
            }
        }

        return null;
    }
}
