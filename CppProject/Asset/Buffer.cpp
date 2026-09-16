#include "Buffer.hpp"

#include "Generated/GmlFunc.hpp"

#if defined(Q_OS_ANDROID)
#include <private/qjni_p.h>
#include <private/qjnihelpers_p.h>

namespace
{
	// Write-side mirror of FileFunc.cpp's android_resolve_content_uri (2026-09-15) - same
	// "content://" gap, opposite direction: QFile can't write a picked SAVE destination
	// either, silently failing Buffer::Save() below for every JSON-backed single-file export
	// that goes through it (object/particles/keyframes/render settings, and project saves
	// once they resolve to a real local path - the project-FOLDER picker is a separate,
	// bigger gap, not this one). Duplicated rather than shared with FileFunc.cpp's copy since
	// Qt's own androidcontentfileengine.cpp duplicates this same small helper privately too,
	// and introducing a shared header across two otherwise-unrelated translation units wasn't
	// worth it for ~15 lines.
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

		// "wt": write + truncate - a save always replaces the destination's full contents.
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
	Buffer::Buffer(StringType filename) : Asset(ID_Buffer)
	{
		QFile readFile(filename);
		if (readFile.open(QFile::ReadOnly))
			data = readFile.readAll();
	}

	Buffer::Buffer(IntType size, BoolType grow, IntType align) : Asset(ID_Buffer)
	{
		data.Alloc(size);
		this->grow = grow;
		this->align = align;
	}

	BoolType Buffer::WriteVar(int type, VarType var, IntType& pos)
	{
		if (pos % align != 0)
			pos = (std::ceil((RealType)pos / align)) * align;

		IntType dataSize = GetDataSize(type);
		if (pos > data.Size() - dataSize) // Not enough space
		{
			if (grow)
				data.Alloc(pos + dataSize);
			else
				return false;
		}

		// Write bytes
		switch (type)
		{
			case buffer_u8:
			{
				CAST_BITS(uint8_t, data.data[pos]) = (uint8_t)var.ToInt();
				pos++;
				break;
			}
			case buffer_s8:
			{
				data.data[pos] = (int8_t)var.ToInt();
				pos++;
				break;
			}
			case buffer_u16:
			{
				CAST_BITS(uint16_t, data.data[pos]) = (uint16_t)var.ToInt();
				pos += 2;
				break;
			}
			case buffer_s16:
			{
				CAST_BITS(int16_t, data.data[pos]) = (int16_t)var.ToInt();
				pos += 2;
				break;
			}
			case buffer_u32:
			{
				CAST_BITS(uint32_t, data.data[pos]) = (uint32_t)var.ToInt();
				pos += 4;
				break;
			}
			case buffer_s32:
			{
				CAST_BITS(int32_t, data.data[pos]) = (int32_t)var.ToInt();
				pos += 4;
				break;
			}
			case buffer_f32:
			{
				CAST_BITS(float, data.data[pos]) = (float)var.ToReal();
				pos += 4;
				break;
			}
			case buffer_f64:
			{
				CAST_BITS(double, data.data[pos]) = (double)var.ToReal();
				pos += 4;
				break;
			}
		}

		return true;
	}
	
	VarType Buffer::ReadVar(int type, IntType& pos)
	{
		IntType dataSize = GetDataSize(type);
		if (pos + dataSize > data.Size())
			return 0;

		switch (type)
		{
			case buffer_u8:
			{
				uint8_t dat = CAST_BITS(uint8_t, data.data[pos]);
				pos++;
				return VarType((IntType)dat);
			}
			case buffer_s8:
			{
				int8_t dat = data.Value(pos);
				pos++;
				return VarType((IntType)dat);
			}
			case buffer_u16:
			{
				uint16_t dat = CAST_BITS(uint16_t, data.data[pos]);
				pos += 2;
				return VarType((IntType)dat);
			}
			case buffer_s16:
			{
				int16_t dat = CAST_BITS(int16_t, data.data[pos]);
				pos += 2;
				return VarType((IntType)dat);
			}
			case buffer_u32:
			{
				uint32_t dat = CAST_BITS(uint32_t, data.data[pos]);
				pos += 4;
				return VarType((IntType)dat);
			}
			case buffer_s32:
			{
				int32_t dat = CAST_BITS(int32_t, data.data[pos]);
				pos += 4;
				return VarType((IntType)dat);
			}
			case buffer_f32:
			{
				float dat = CAST_BITS(float, data.data[pos]);
				pos += 4;
				return VarType((RealType)dat);
			}
			case buffer_f64:
			{
				double dat = CAST_BITS(double, data.data[pos]);
				pos += 8;
				return VarType((RealType)dat);
			}
		}

		return 0;
	}

	void Buffer::Save(StringType filename)
	{
#if defined(Q_OS_ANDROID)
		if (filename.StartsWith("content://"))
		{
			if (!WriteBytesToAndroidContentUri(filename.QStr(), (char*)data.Data(), data.Size()))
				WARNING("Could not save buffer to content URI " + filename.QStr());
			return;
		}
#endif
		QFile file(filename);
		AddPerms(file);
		if (file.open(QFile::WriteOnly))
			file.write((char*)data.Data(), data.Size());
		else
			WARNING("Could not save buffer to " + filename.QStr() + ": " + file.errorString());
	}

	IntType Buffer::GetDataSize(int type)
	{
		switch (type)
		{
			case buffer_u8: return 1;
			case buffer_s8: return 1;
			case buffer_u16: return 2;
			case buffer_s16: return 2;
			case buffer_u32: return 4;
			case buffer_s32: return 4;
			case buffer_f32: return 4;
			case buffer_f64: return 8;
		}
		return 0;
	}
}