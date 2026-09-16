#include "Generated/Scripts.hpp"
#include "World/GZIP.hpp"

#include <QDesktopServices>
#include <QTextStream>
#include <QUrl>

#define ZIP_STATIC
#include <zip.h>

#if defined(Q_OS_ANDROID)
#include <private/qjni_p.h>
#include <private/qjnihelpers_p.h>

namespace
{
	// Same helper as Buffer.cpp's (2026-09-15) - lib_file_copy below is the native C++ target
	// external_call(lib_file_copy, ...) resolves to in the compiled app (surface_save_lib.gml's
	// "write to a local temp, then lib_file_copy to the real destination" pattern - PNG/image
	// export's actual path), and needs the same content:// destination handling QFile::copy()
	// can't do. Duplicated rather than shared across translation units, matching
	// Buffer.cpp/Qt's own androidcontentfileengine.cpp for the same small helper.
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

	bool WriteBytesToAndroidContentUri(const QString& uriStr, const char* bytes, qint64 size)
	{
		JniExceptionCleaner exceptionCleaner;

		QJNIObjectPrivate juri = QJNIObjectPrivate::callStaticObjectMethod(
			"android/net/Uri", "parse", "(Ljava/lang/String;)Landroid/net/Uri;",
			QJNIObjectPrivate::fromString(uriStr).object());

		if (!juri.isValid())
			return false;

		QJNIObjectPrivate contentResolver = QJNIObjectPrivate(QtAndroidPrivate::context())
			.callObjectMethod("getContentResolver", "()Landroid/content/ContentResolver;");

		QJNIObjectPrivate pfd = contentResolver.callObjectMethod("openFileDescriptor",
			"(Landroid/net/Uri;Ljava/lang/String;)Landroid/os/ParcelFileDescriptor;",
			juri.object(), QJNIObjectPrivate::fromString("wt").object());

		if (exceptionCleaner.clean() || !pfd.isValid())
			return false;

		jint fd = pfd.callMethod<jint>("getFd", "()I");
		if (fd < 0)
			return false;

		QFile out;
		bool ok = false;
		if (out.open(fd, QFile::WriteOnly | QFile::Truncate, QFile::DontCloseHandle))
		{
			ok = (out.write(bytes, size) == size);
			out.close();
		}

		pfd.callMethod<void>("close");
		return ok;
	}
}
#endif

namespace CppProject
{
	RealType lib_open_url(StringType url)
	{
		if (!url.StartsWith("http"))
			url = "file:///" + url;
		return QDesktopServices::openUrl((QString)url);
	}

	RealType lib_execute(StringType file, StringType param, RealType wait)
	{
		return 0.0;
	}

	RealType lib_unzip(StringType src, StringType dst)
	{
		int err;
		std::string srcStd = src.ToStdString();
		struct zip* za = zip_open(srcStd.c_str(), 0, &err);
		if (!za)
		{
			WARNING("Could not unzip " + src);
			return -1;
		}

		IntType numEntries = zip_get_num_entries(za, 0);
		IntType files = 0, numFiles = numEntries;
		for (int i = 0; i < numEntries; i++)
		{
			struct zip_stat sb;
			if (zip_stat_index(za, i, 0, &sb))
			{
				WARNING("Could not extract file " + StringType(sb.name));
				continue;
			}

			QString fileName = dst + sb.name;
			QFileInfo info(fileName);
			if (fileName.endsWith("/")) // Skip directories
			{
				numFiles--;
				continue;
			}

			// Create path of directories to file if needed
			if (!QDir(info.path()).exists())
				if (!QDir().mkpath(info.path()))
					WARNING("Could not create path " + info.path());

			// Open destination file for writing
			struct zip_file* zf = zip_fopen_index(za, i, 0);
			QFile file(fileName);
			AddPerms(file);

			if (!zf || !file.open(QFile::WriteOnly))
			{
				WARNING("Could not extract file " + QString(sb.name) + ": " + file.errorString());
				continue;
			}

			int sum = 0;
			bool readErr = false;
			while (sum != sb.size)
			{
				char buf[1024];
				int readNum = zip_fread(zf, buf, sizeof(buf));
				if (readNum < 0)
				{
					WARNING("Could not extract file " + StringType(sb.name));
					readErr = true;
					break;
				}
				if (file.write(buf, readNum) < 0)
				{
					WARNING("Could not extract file " + StringType(sb.name));
					readErr = true;
					break;
				}
				sum += readNum;
			}

			zip_fclose(zf);
			if (!readErr)
				files++;
		}

		if (zip_close(za) < 0)
			return -1;
		
		DEBUG("Extracted " + NumStr(files) + "/" + NumStr(numFiles) + " files");
		return files == numFiles;
	}

	RealType lib_gzunzip(StringType src, StringType dst)
	{
		Gzip::Decompress(src, dst);
		return 0;
	}

	RealType lib_file_rename(StringType src, StringType dst)
	{
		QDir srcDir(src);
		if (srcDir.exists()) // Directory rename
		{
			QDir dstDir(dst);
			if (dstDir.exists() && !dstDir.removeRecursively())
				WARNING("Could not remove directory " + dst);

			BoolType ok = srcDir.rename(src, dst);
			if (!ok)
				WARNING("Could not rename directory " + src);

			return ok;
		}

		// File rename
		QFile srcFile(src);
		if (!srcFile.exists())
			return false;

		QFile dstFile(dst);
		if (dstFile.exists())
		{
			AddPerms(dstFile);
			if (!dstFile.remove())
				WARNING("Could not delete file " + dst.QStr() + ": " + dstFile.errorString());
		}

		AddPerms(srcFile);
		BoolType ok = srcFile.rename(dst);
		if (!ok)
			WARNING("Could not rename file " + src.QStr() + ": " + srcFile.errorString());
		return ok;
	}

	// Added for the Android Data/ bundle-seeding verification (Fase 3, CLAUDE.md §17,
	// 2026-09-10) - QFileInfo::size() works transparently against ":/" Qt resource paths
	// too, so the same call verifies both the bundled source and the copied destination.
	// Returns -1 if the file doesn't exist, matching the "not found" convention other
	// lib_* functions use via file_exists_lib() rather than throwing.
	RealType lib_file_size(StringType fn)
	{
		QFileInfo info((QString)fn);
		if (!info.exists())
			return -1;
		return (RealType)info.size();
	}

	RealType lib_file_copy(StringType src, StringType dst)
	{
		QFile srcFile(src);
		if (!srcFile.exists())
			return false;

#if defined(Q_OS_ANDROID)
		if (dst.StartsWith("content://"))
		{
			AddPerms(srcFile);
			if (!srcFile.open(QFile::ReadOnly))
			{
				WARNING("Could not open " + src.QStr() + " to copy to content URI: " + srcFile.errorString());
				return false;
			}
			QByteArray bytes = srcFile.readAll();
			srcFile.close();

			BoolType ok = WriteBytesToAndroidContentUri(dst.QStr(), bytes.constData(), bytes.size());
			if (!ok)
				WARNING("Could not copy " + src.QStr() + " to content URI " + dst.QStr());
			return ok;
		}
#endif

		QFile dstFile(dst);
		if (dstFile.exists())
		{
			AddPerms(dstFile);
			if (!dstFile.remove(dst))
				WARNING("Could not delete file " + dst.QStr() + ": " + srcFile.errorString());
		}

		AddPerms(srcFile);
		BoolType ok = srcFile.copy(dst);
		if (!ok)
			WARNING("Could not copy file " + src.QStr() + ": " + srcFile.errorString());
		return ok;
	}

	RealType lib_file_delete(StringType fn)
	{
		QFile file(fn);
		if (!file.exists())
			return false;

		AddPerms(file);
		BoolType ok = file.remove();
		if (!ok)
			WARNING("Could not delete file " + fn.QStr() + ": " + file.errorString());
		return ok;
	}

	RealType lib_file_exists(StringType file)
	{
		return QFile::exists(file);
	}

	RealType lib_directory_create(StringType dir)
	{
		BoolType ok = QDir().mkpath(dir);
		if (!ok)
			WARNING("Could not create directory " + dir);
		return ok;
	}

	RealType lib_directory_delete(StringType dir)
	{
		BoolType ok = QDir(dir).removeRecursively();
		if (!ok)
			WARNING("Could not delete directory " + dir);
		return ok;
	}

	RealType lib_directory_exists(StringType dir)
	{
		return QDir(dir).exists();
	}

	RealType lib_json_file_convert_unicode(StringType src, StringType dst)
	{
		return lib_file_copy(src, dst);
	}
}