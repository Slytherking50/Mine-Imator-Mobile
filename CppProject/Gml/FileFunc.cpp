#include "Generated/Scripts.hpp"

#include "Asset/TextFile.hpp"
#include "AppHandler.hpp"

#include <QDirIterator>
#include <QFileDialog>
#include <QFileInfo>
#include <QJsonParseError>
#include <QJsonObject>
#include <QJsonArray>

#if defined(Q_OS_ANDROID)
#include <private/qjni_p.h>
#include <private/qjnihelpers_p.h>
#include <QtCore/qcoreapplication.h>

// Mirrors the same-named, non-exported helper in Qt's own
// qtbase/src/plugins/platforms/android/androidcontentfileengine.cpp - not reusable from here
// (platform plugin internal), so duplicated rather than pulled in some other way.
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

namespace CppProject
{
	QDirIterator* fileFindIt = nullptr;
	// Separate iterator/instance from fileFindIt above (2026-09-16, Fase 5/B37) - directory_find_*
	// and file_find_* enumerate different QDir::Filter sets (Dirs vs Files) and neither caller
	// nests calls to the other today, but keeping them independent avoids a subtle bug if that
	// ever changes (one find_next() call silently stealing the other's cursor).
	QDirIterator* dirFindIt = nullptr;

	BoolType file_delete(StringType file)
	{
		return lib_file_delete(file);
	}

	BoolType file_exists(StringType file)
	{
		return lib_file_exists(file);
	}

	void file_find_close()
	{
		deleteAndReset(fileFindIt);
	}

	StringType file_find_first(StringType dir, IntType attr)
	{
		deleteAndReset(fileFindIt);

		int wildCardIndex = dir.IndexOf("*"); // Wildcard not supported (unused in code)
		if (wildCardIndex >= 0)
			dir = dir.Left(wildCardIndex);

		fileFindIt = new QDirIterator(dir, QDir::Files | QDir::NoDotAndDotDot);
		if (fileFindIt->hasNext())
			return filename_name(fileFindIt->next());

		return "";
	}

	StringType file_find_next()
	{
		if (fileFindIt && fileFindIt->hasNext())
			return filename_name(fileFindIt->next());
		return "";
	}

	// directory_find_first/_next/_close (2026-09-16, Fase 5/B37): no built-in GML/existing lib
	// function ever enumerated subdirectories - file_find_first above is hardcoded to
	// QDir::Files, and its "attr" argument (meant to mirror real GameMaker's fa_directory etc.)
	// was already unused/vestigial before this change (grep confirms fa_directory was never
	// defined anywhere in this project). Added for the new Android folder picker
	// (popup_folder_picker_draw.gml) rather than overloading file_find_first's ignored attr
	// param, to avoid any risk to the existing file-only behavior every other caller of
	// file_find_first relies on today.
	void directory_find_close()
	{
		deleteAndReset(dirFindIt);
	}

	StringType directory_find_first(StringType dir)
	{
		deleteAndReset(dirFindIt);

		dirFindIt = new QDirIterator(dir, QDir::Dirs | QDir::NoDotAndDotDot);
		if (dirFindIt->hasNext())
			return filename_name(dirFindIt->next());

		return "";
	}

	StringType directory_find_next()
	{
		if (dirFindIt && dirFindIt->hasNext())
			return filename_name(dirFindIt->next());
		return "";
	}

	BoolType file_rename(StringType src, StringType dst)
	{
		return lib_file_rename(src, dst);
	}

	void file_text_close(IntType id)
	{
		if (TextFile* tFile = FindTextFile(id))
			delete tFile;
	}

	BoolType file_text_eof(IntType id)
	{
		if (TextFile* tFile = FindTextFile(id))
			return tFile->IsEof();
		return false;
	}

	IntType file_text_open_append(StringType file)
	{
		QFile* qFile = new QFile(file);
		if (qFile->open(QFile::Append | QFile::Text))
			return (new TextFile(qFile, false))->id;
		else
			delete qFile;
		return -1;
	}

	IntType file_text_open_read(StringType file)
	{
		QFile* qFile = new QFile(file);
		if (qFile->open(QFile::ReadOnly | QFile::Text))
			return (new TextFile(qFile, true))->id;
		else
			delete qFile;
		return -1;
	}

	IntType file_text_open_write(StringType file)
	{
		QFile* qFile = new QFile(file);
		AddPerms(*qFile);
		if (qFile->open(QFile::WriteOnly | QFile::Text))
			return (new TextFile(qFile, false))->id;
		else
		{
			WARNING("Could not open file " + file.QStr() + ": " + qFile->errorString());
			delete qFile;
		}
		return -1;
	}

	StringType file_text_read_string(IntType id)
	{
		if (TextFile* tFile = FindTextFile(id))
			return tFile->ReadWord();
		return "";
	}

	StringType file_text_readln(IntType id)
	{
		if (TextFile* tFile = FindTextFile(id))
			return tFile->ReadLine();
		return "";
	}

	IntType file_text_write_string(IntType id, StringType str)
	{
		if (TextFile* tFile = FindTextFile(id))
			if (tFile->stream)
				*tFile->stream << str;
		return 0;
	}

	IntType file_text_writeln(IntType id)
	{
		if (TextFile* tFile = FindTextFile(id))
			if (tFile->stream)
				*tFile->stream << "\n";
		return 0;
	}

	// Android content:// URIs (Android SAF dialog results, 2026-09-15) have no filesystem
	// path/directory/suffix for QFileInfo to parse - it would just mangle the opaque document
	// id instead. Every filename_* helper below passes one through unchanged rather than
	// letting QFileInfo corrupt it; a content:// URI already carries the right name/extension
	// on the document itself (set via the native picker), nothing here needs to re-derive it.
	StringType filename_change_ext(StringType file, StringType newext)
	{
		if (file.StartsWith("content://"))
			return file;
		QFileInfo info(file);
		return info.path() + "/" + info.completeBaseName() + newext;
	}

	StringType filename_dir(StringType file)
	{
		if (file.StartsWith("content://"))
			return file;
		return QFileInfo(file).path();
	}

	StringType filename_ext(StringType file)
	{
		if (file.StartsWith("content://"))
			return "";
		QString suffix = QFileInfo(file).suffix();
		if (suffix.isEmpty())
			return "";
		return "." + suffix;
	}

	StringType filename_name(StringType file)
	{
		if (file.StartsWith("content://"))
			return file;
		return QFileInfo(file).fileName();
	}

	StringType filename_path(StringType file)
	{
		if (file.StartsWith("content://"))
			return file;
		return QFileInfo(file).path() + "/";
	}

	QStringList GetFilenameFilterList(StringType str)
	{
		if (str.IsEmpty())
			return QStringList();

		QStringList list;
		QStringList strSplit = str.Split('|');
		for (IntType i = 0; i < strSplit.size(); i += 2)
		{
			QString name = strSplit.at(i);
			QString filter = strSplit.at(i + 1);
			filter.replace(";", " ");

			IntType parIndex = name.indexOf("(");
			if (parIndex >= 0)
				name = name.left(parIndex - 1);

			list.append(name + " (" + filter + ")");
		}
		return list;
	}

	QString GetFilenameFilterDefaultSuffix(StringType str)
	{
		if (str.IsEmpty())
			return "";

		QStringList strSplit = str.Split('|');
		if (strSplit.size() < 2)
			return "";

		QString filter = strSplit.at(1);
		filter.replace(";", " ");
		QStringList patterns = filter.split(QChar(' '), Qt::SkipEmptyParts);
		for (const QString& pattern : patterns)
		{
			if (pattern.startsWith("*.") && pattern.size() > 2)
				return pattern.mid(2);
		}
		return "";
	}

#if defined(Q_OS_ANDROID)
	// QFileDialog's native Android picker (used below) is documented to return a "content://"
	// URI, not a real filesystem path - Qt's own AndroidContentFileEngine is supposed to let
	// QFile open those directly, but on this device/build it doesn't: QFile::open() on such a
	// URI just fails, and json_load()/similar callers see it as a normal open failure -
	// exactly the "corrupto"/"versión no compatible" the user hit opening BOTH a .miproject
	// and a texture through "Abrir proyecto"/"Importar recurso" (2026-09-15, confirmed via
	// log.txt: "Could not parse JSON file: content://com.android.providers.downloads.documents/
	// document/342" - the raw URI string reaching json_load() unresolved). Rather than debug
	// Qt's own broken path further, this bypasses it: resolve the URI ourselves via raw JNI
	// (QJNIObjectPrivate/QtAndroidPrivate - part of QtCore's already-built Android platform
	// support, NOT the separate QtAndroidExtras module confirmed missing from this Qt install,
	// so no Qt rebuild needed) and copy its bytes into a real local file under
	// user_directory_get(), then hand GML that ordinary path - every existing reader
	// (json_load, sprite loading, etc.) keeps working completely unchanged. Read-side only
	// (get_open_filename_ext) - the save side has a different, bigger gap (file_dialog_save_
	// project uses the save dialog as a folder picker, which doesn't map onto SAF's per-file
	// model at all) tracked separately, not fixed here.
	StringType android_resolve_content_uri(StringType uriStr)
	{
		JniExceptionCleaner exceptionCleaner;
		Q_UNUSED(exceptionCleaner);

		QJNIObjectPrivate juri = QJNIObjectPrivate::callStaticObjectMethod(
			"android/net/Uri", "parse", "(Ljava/lang/String;)Landroid/net/Uri;",
			QJNIObjectPrivate::fromString(uriStr.QStr()).object());

		if (!juri.isValid())
		{
			DEBUG("android_resolve_content_uri: Uri.parse failed for " + uriStr.QStr());
			return "";
		}

		QJNIObjectPrivate contentResolver = QJNIObjectPrivate(QtAndroidPrivate::context())
			.callObjectMethod("getContentResolver", "()Landroid/content/ContentResolver;");

		// Display name (OpenableColumns.DISPLAY_NAME) - the URI itself is an opaque numeric
		// document id ("document/342"), no usable extension in it. Texture/model loading
		// elsewhere in this codebase dispatches on file extension, so the local copy needs to
		// keep the real one instead of inventing a generic ".tmp".
		QString displayName = "content_import";
		{
			QJNIObjectPrivate cursor = contentResolver.callObjectMethod("query",
				"(Landroid/net/Uri;[Ljava/lang/String;Ljava/lang/String;[Ljava/lang/String;Ljava/lang/String;)Landroid/database/Cursor;",
				juri.object(), nullptr, nullptr, nullptr, nullptr);

			if (cursor.isValid() && cursor.callMethod<jboolean>("moveToFirst"))
			{
				jint nameCol = cursor.callMethod<jint>("getColumnIndex",
					"(Ljava/lang/String;)I", QJNIObjectPrivate::fromString("_display_name").object());

				if (nameCol >= 0)
				{
					QJNIObjectPrivate jname = cursor.callObjectMethod("getString", "(I)Ljava/lang/String;", nameCol);
					if (jname.isValid())
						displayName = jname.toString();
				}
			}

			if (cursor.isValid())
				cursor.callMethod<void>("close");
		}

		// Not every content provider's DISPLAY_NAME carries a real extension (confirmed
		// against the Downloads provider on the reference device, never against others) -
		// falls back to the literal "content_import" above, or some providers return a bare
		// document id with no suffix at all. Since res_load()/new_res() (GmProject) and the
		// image loaders under this dispatch by file extension, a missing one silently mis-
		// detects the format instead of erroring cleanly (suspected contributor to B30, a
		// skin-picker crash reported on a second Android device - unconfirmed without that
		// device's log.txt, but this gap is real regardless of whether it's the exact cause).
		// MIME type (ContentResolver.getType(), works for every provider, not just the ones
		// that also populate DISPLAY_NAME) is the correct Android-native fallback source.
		if (QFileInfo(displayName).suffix().isEmpty())
		{
			QJNIObjectPrivate jtype = contentResolver.callObjectMethod("getType",
				"(Landroid/net/Uri;)Ljava/lang/String;", juri.object());
			if (jtype.isValid())
			{
				QString mime = jtype.toString();
				QString ext;
				if (mime == "image/png") ext = "png";
				else if (mime == "image/jpeg") ext = "jpg";
				else if (mime == "application/zip" || mime == "application/x-zip-compressed") ext = "zip";

				if (!ext.isEmpty())
					displayName += "." + ext;
			}
		}

		QJNIObjectPrivate pfd = contentResolver.callObjectMethod("openFileDescriptor",
			"(Landroid/net/Uri;Ljava/lang/String;)Landroid/os/ParcelFileDescriptor;",
			juri.object(), QJNIObjectPrivate::fromString("r").object());

		if (exceptionCleaner.clean())
		{
			DEBUG("android_resolve_content_uri: JNI exception opening " + uriStr.QStr());
			return "";
		}

		if (!pfd.isValid())
		{
			DEBUG("android_resolve_content_uri: openFileDescriptor returned null for " + uriStr.QStr());
			return "";
		}

		jint fd = pfd.callMethod<jint>("getFd", "()I");
		if (fd < 0)
		{
			DEBUG("android_resolve_content_uri: invalid fd for " + uriStr.QStr());
			return "";
		}

		QString localPath = user_directory_get().QStr() + "content_import_" + displayName;

		QFile src;
		if (!src.open(fd, QFile::ReadOnly, QFile::DontCloseHandle))
		{
			DEBUG("android_resolve_content_uri: could not wrap fd as QFile for " + uriStr.QStr());
			pfd.callMethod<void>("close");
			return "";
		}

		QByteArray bytes = src.readAll();
		src.close();
		pfd.callMethod<void>("close");

		QFile dst(localPath);
		if (!dst.open(QFile::WriteOnly | QFile::Truncate))
		{
			DEBUG("android_resolve_content_uri: could not write local copy " + localPath);
			return "";
		}
		dst.write(bytes);
		dst.close();

		DEBUG("android_resolve_content_uri: copied " + uriStr.QStr() + " (" + QString::number(bytes.size()) + " bytes) -> " + localPath);

		return StringType(localPath);
	}
#endif

	StringType get_open_filename_ext(StringType filter, StringType file, StringType dir, StringType caption)
	{
		QFileDialog fd;
		fd.setModal(true);
		fd.setAcceptMode(QFileDialog::AcceptOpen);
		fd.setFileMode(QFileDialog::ExistingFile);
		fd.setNameFilters(GetFilenameFilterList(filter));
		if (file != "")
		{
			if (!file.Contains("/") && !dir.IsEmpty())
				file = dir + "/" + file;
			fd.selectFile(file);
		}
		else if (!dir.IsEmpty())
			fd.setDirectory(dir);
		fd.setWindowTitle(caption);
		if (!App->ExecDialog(&fd))
			return "";

		QStringList files = fd.selectedFiles();
		if (files.size() > 0)
		{
			StringType picked = files[0];
#if defined(Q_OS_ANDROID)
			if (picked.StartsWith("content://"))
				return android_resolve_content_uri(picked);
#endif
			return picked;
		}
		return "";
	}

	StringType get_save_filename_ext(StringType filter, StringType file, StringType dir, StringType caption)
	{
		QFileDialog fd;
		fd.setModal(true);
		fd.setAcceptMode(QFileDialog::AcceptSave);
		fd.setFileMode(QFileDialog::AnyFile);
		fd.setNameFilters(GetFilenameFilterList(filter));
		QString defaultSuffix = GetFilenameFilterDefaultSuffix(filter);
		if (!defaultSuffix.isEmpty())
			fd.setDefaultSuffix(defaultSuffix);
		if (file != "")
		{
			if (!file.Contains("/") && !dir.IsEmpty())
				file = dir + "/" + file;
			fd.selectFile(file);
		}
		else if (!dir.IsEmpty())
			fd.setDirectory(dir);
		fd.setWindowTitle(caption);
		if (!App->ExecDialog(&fd))
			return "";

		QStringList files = fd.selectedFiles();
		if (files.size() > 0)
		{
			QString filename = files[0];
			if (!defaultSuffix.isEmpty() && QFileInfo(filename).suffix().isEmpty())
				filename += "." + defaultSuffix;
			return filename;
		}
		return "";
	}

	IntType json_load_from_string(StringType json, IntType typeMapId = 0)
	{
		if (json.IsEmpty() || (!json.StartsWith("{") && !json.StartsWith("[")))
			return -1;

		IntHashMap* typeMap = FindSubAssetOpt(IntHashMap, Map, typeMapId);
		QJsonParseError jsonError;
		QJsonDocument loadDoc = QJsonDocument::fromJson(json.ToUtf8(), &jsonError);
		if (jsonError.error)
		{
			global::json_error = jsonError.errorString() + " on line " + NumStr(json.Left(jsonError.offset).Count("\n"));
			DEBUG("JSON error: " + global::json_error);
			return -1;
		}

		function<VarType(const QJsonValue&, e_json_type& outType)> loadValue;
		function<IntType(const QJsonArray&)> loadArray;
		function<IntType(const QJsonObject&)> loadObject;

		loadValue = [](const QJsonValue& val, e_json_type& outType)
		{
			if (val.isBool())
			{
				outType = e_json_type_BOOL;
				return VarType(val.toBool());
			}
			else if (val.isDouble())
			{
				outType = e_json_type_NUMBER;
				return VarType((RealType)val.toDouble());
			}
			else if (val.isString())
			{
				outType = e_json_type_STRING;
				return VarType(val.toString());
			}
			else if (val.isNull())
			{
				outType = e_json_type_NULL_;
				return VarType(null_);
			}

			WARNING("Unknown QJsonValue");
			return VarType();
		};

		loadArray = [&loadValue, &loadArray, &loadObject](const QJsonArray& arr)
		{
			List* list = new List;
			list->vec.reserve(arr.size());
			for (const QJsonValue& val : arr)
			{
				e_json_type jsonType;
				if (val.isArray())
					list->vec.append({ loadArray(val.toArray()), ds_type_list });
				else if (val.isObject())
					list->vec.append({ loadObject(val.toObject()), ds_type_map });
				else
					list->vec.append({ loadValue(val, jsonType), 0 });
			}
			return list->id;
		};

		loadObject = [typeMap, &loadValue, &loadArray, &loadObject](const QJsonObject& obj)
		{
			StringHashMap* map = new StringHashMap;
			StringHashMap* mapTypes = nullptr;

			// Store types
			if (typeMap)
			{
				mapTypes = new StringHashMap;
				typeMap->hash[map->id] = { mapTypes->id, ds_type_map };
			}

			for (StringType key : obj.keys())
			{
				const QJsonValue& val = obj.value(key);
				e_json_type jsonType;

				if (val.isArray())
				{
					jsonType = e_json_type_ARRAY;
					map->hash[key] = { loadArray(val.toArray()), ds_type_list };
				}
				else if (val.isObject())
				{
					jsonType = e_json_type_OBJECT;
					map->hash[key] = { loadObject(val.toObject()), ds_type_map };
				}
				else
				{
					VarType var = loadValue(val, jsonType);
					map->hash[key] = { var, 0 };
				}

				if (mapTypes)
					mapTypes->hash[key].value = jsonType;
			}

			return map->id;
		};

		return loadObject(loadDoc.object());
	}

	IntType json_decode(StringType json)
	{
		return json_load_from_string(json);
	}

	IntType json_load(VarArgs args)
	{
		QFile file(args[0].ToStr());
		if (!file.open(QFile::ReadOnly))
			return -1;
		
		IntType typeMap = 0;
		if (args.Size() > 1)
			typeMap = args[1];
		return json_load_from_string(file.readAll(), typeMap);
	}

	StringType json_string_encode(StringType arg)
	{
		QString str = arg.QStr();
		IntType newLen = 0;
		for (QChar c : str)
		{
			if (c == '\n' || c == '\t' || c == '"' || c == '\\')
				newLen += 2;
			else if (c.unicode() > 127)
				newLen += 5;
			else
				newLen++;
		}

		if (str.length() == newLen)
			return arg;

		QString nstr;
		nstr.reserve(newLen);
		for (QChar c : str)
		{
			if (c == '\n')
				nstr += "\\n";
			else if (c == '\t')
				nstr += "\\t";
			else if (c == '"')
				nstr += "\\\"";
			else if (c == '\\')
				nstr += "\\\\";
			else if (c.unicode() > 127)
				nstr += "\\u" + QString("%1").arg(c.unicode(), 4, 16, QLatin1Char('0')).toLower();
			else
				nstr += c;
		}

		return nstr;
	}
}
