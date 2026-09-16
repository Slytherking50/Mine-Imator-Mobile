#if API_OPENGL
#ifndef Q_OS_ANDROID
// See Shader.cpp for why this is excluded on Android (GLclampd doesn't exist in ES headers).
#undef __glext_h_
#include <qopenglext.h>
#endif

#include "Shader.hpp"
#include "Render/GraphicsApiHandler.hpp"
#include "Render/Vertex.hpp"

namespace CppProject
{
	void Shader::LoadCode(QString vsCode, QString fsCode, BoolType useCache)
	{
		// Batching requires SSBO (GL 4.3+ only)
		if (!gl43Supported)
			useBatching = false;

		// Free program and SSBO
		deleteAndReset(program);
		if (glSsboId)
			GFX->glDeleteBuffers(1, &glSsboId);
		glSsboId = 0;

		// Convert from GLES to GLSL for a given shader
		auto processCode = [&](QString code, BoolType isVertex)
		{
			QString header = "";

			// Move preprocessor declarations to header
			for (QString line : code.split("\n"))
			{
				if (line.startsWith("#"))
				{
					header = line + "\n" + header;
					code.replace(line + "\n", "");
				}
			}

			if (!isVertex)
			{
				// Single rendertarget
				if (code.contains("gl_FragColor"))
				{
					header += "layout(location = 0) out vec4 out_FragColor;\n";
					code.replace("gl_FragColor", "out_FragColor");
					numOutputs = 1;
				}
				else // Multiple rendertargets
				{
					while (true)
					{
						QString outNumStr = NumStr(numOutputs);
						QString outData = "gl_FragData[" + outNumStr + "]";
						if (!code.contains(outData))
							break;

						header += "layout(location = " + outNumStr + ") out vec4 out_FragData" + outNumStr + ";\n";
						code.replace(outData, "out_FragData" + outNumStr);
						numOutputs++;
					}
				}
			}

			// Texture2D function to sample using UvRect uniform
			if (code.contains("texture2D("))
			{
				QString setLod = "";
				if (gl40Supported)
					setLod = "\tvec2 uvLod = uvRect.xy + uv * uvRect.zw;\n"
					"\tuvLod.y = 1.0 - uvLod.y;\n"
					"\tlod = textureQueryLod(s, uvLod).y;\n";
				header += "\n"
					"vec4 _sampleUvRect(sampler2D s, vec4 uvRect, bool repeat, vec2 uv)\n"
					"{\n"
					"\tfloat lod = 0.0;\n" +
					setLod +
					"\tif (repeat) uv = mod(uv, vec2(1.0, 1.0));\n"
					"\tuv = uvRect.xy + uv * uvRect.zw;\n"
					"\tuv.y = 1.0 - uv.y;\n"
					"\treturn textureLod(s, uv, lod);\n"
					"}\n\n";
			}

			// New keywords
			code.replace("attribute", "in");
			code.replace("varying", isVertex ? "out" : "in");

			// Convert attributes (vertex)
			if (isVertex && vertexFormat == VERTEX_BUFFER)
			{
				code.replace("in vec3 in_Normal;\n", "");
				code.replace("in vec4 in_Colour;\n", "");
				code.replace("in vec4 in_Wave;\n", "");
				code.replace("in vec3 in_Tangent;\n", "");
				header += "in uint _aNormal;\n"
					"in uint _aColor;\n"
					"in uint _aData;\n"
					"in uint _aTangent;\n";

			#ifdef Q_OS_ANDROID
				// GLSL ES forbids non-const global initializers - desktop GLSL allows a
				// global's initializer to reference another global/attribute (which is what
				// the #else branch below does), ES doesn't. Confirmed 2026-09-08 on a real
				// device: "ERROR: '_aTangent' : Only consts can be used in a global
				// initializer" for every VERTEX_BUFFER-format shader.
				//
				// First attempt - moving these to LOCAL declarations inside main() - also
				// failed: some shaders (e.g. shader_replace.vsh) call helper functions
				// (getWind(), defined above main()) that reference in_Wave etc. directly as
				// globals; a main()-local declaration is invisible to them ("undeclared
				// identifier: in_Wave", also confirmed on-device). Fix: keep them as globals,
				// but WITHOUT an initializer (legal in ES - only initializer expressions must
				// be const, a bare declaration isn't one), then ASSIGN their real value as
				// the first statement inside main() - a plain assignment isn't a "global
				// initializer" either, and by the time any helper function actually runs
				// (they're only ever called from within main(), never before it), the
				// assignment has already happened.
				header += "vec3 in_Normal;\n"
					"vec4 in_Colour;\n"
					"vec4 in_Wave;\n"
					"vec3 in_Tangent;\n";

				QString unpackAssignments =
					"in_Normal = " UNPACK_VERTEX_NORMAL("_aNormal") ";\n"
					"in_Colour = " UNPACK_VERTEX_COLOR("_aColor") ";\n"
					"in_Wave = " UNPACK_VERTEX_WAVE("_aData") ";\n"
					"in_Tangent = " UNPACK_VERTEX_NORMAL("_aTangent") ";\n";
				QRegularExpression mainRe("void\\s+main\\s*\\(\\s*\\)\\s*\\{");
				QRegularExpressionMatch mainMatch = mainRe.match(code);
				if (mainMatch.hasMatch())
					code.insert(mainMatch.capturedEnd(), "\n" + unpackAssignments);
			#else
				header += "vec3 in_Normal = " UNPACK_VERTEX_NORMAL("_aNormal") ";\n"
					"vec4 in_Colour = " UNPACK_VERTEX_COLOR("_aColor") ";\n"
					"vec4 in_Wave = " UNPACK_VERTEX_WAVE("_aData") ";\n"
					"vec3 in_Tangent = " UNPACK_VERTEX_NORMAL("_aTangent") ";\n";
			#endif
			}

			if (useBatching)
			{
				// Add index attribute & variant
				if (isVertex)
				{
					code.replace("gl_Position = ", "_vObjIndex = _objIndex;\n\tgl_Position = ");
					header += "flat out uint _vObjIndex;\nuint _objIndex = _aData >> 16;\n";
				}
				else
					header += "flat in uint _vObjIndex;\n";
			}

			// Header with nice separation
			if (header != "")
				code = header + "\n/// ----------------------------------- ///\n\n" + code;

			// Load uniforms/matrices
			LoadCodeCommon(code);

			return code;
		};

		// Process Vertex & Fragment code
		vsCode = processCode(vsCode, true);
		fsCode = processCode(fsCode, false);

		// Generate SSBO buffer statement
		if (useBatching)
		{
			// Get maximum objects allowed
			batchBufferObjectSize = ceil(batchBufferObjectSize / 16.0) * 16;
			batchBufferMaxObjects = MAX_BATCH_BUFFER_SIZE / batchBufferObjectSize;
			batchBufferSize = batchBufferMaxObjects * batchBufferObjectSize;

			// Add SSBO for uniform data
			QString ssboDef = "layout(std430, binding = 2) buffer _ssbo\n{\n";
			ssboDef += "\tstruct\n\t{\n";
			for (IntType i = 0; i < numUniforms; i++)
			{
				UniformState& uni = uniforms[i];
				if (uni.isStatic)
					continue;

				ssboDef += "\t\t" + uni.typeName + " " + uni.name + ";\n";

				// Remove uniform from header and add array accesor with vertex index
				QRegularExpression uniHeader("uniform " + uni.typeName + " " + uni.name + ";(.*?)\n");
				QRegularExpression uniFind("\\b" + uni.name + "\\b");
				QString uniReplVs = "_obj[_objIndex]." + uni.name;
				QString uniReplFs = "_obj[_vObjIndex]." + uni.name;
				vsCode = vsCode.replace(uniHeader, "");
				fsCode = fsCode.replace(uniHeader, "");
				vsCode = vsCode.replace(uniFind, uniReplVs);
				fsCode = fsCode.replace(uniFind, uniReplFs);
			}

			ssboDef += "\t} _obj[" + NumStr(batchBufferMaxObjects) + "];\n};\n\n";
			vsCode = ssboDef + vsCode;
			fsCode = ssboDef + fsCode;
		}

		// Add defines
		QString defines = "#version " + glslVersion + "\n";
	#ifndef Q_OS_ANDROID
		// GL_ARB_* is desktop-only extension naming (ARB = desktop OpenGL's Architecture
		// Review Board) - meaningless on ES, which doesn't have this extension under any
		// name. Not needed there anyway: explicit attribute locations (layout(location=N))
		// are already core in GLSL ES 3.00+, the version Android requests (Shader.cpp Init()).
		defines += "#extension GL_ARB_explicit_attrib_location : enable\n";
	#else
		// GLSL ES 3.00 spec (4.5.3): fragment shaders have NO default precision for float/
		// int/sampler types - a spec-compliant compiler must reject any fragment shader
		// that uses them without either a precision statement or a per-declaration
		// qualifier. None of this project's 53 shaders (GmProject's GameMaker-dialect ones
		// nor the 6 C++-only ones) have ever had a precision qualifier anywhere (confirmed
		// 2026-09-09, Fase 2 code audit) - the desktop GLSL dialect they're written in has
		// no such concept. That they compile at all on the one real device tested so far
		// (Adreno 610) only proves that THIS driver is lenient enough to supply an implicit
		// default - not that every ES driver is. Qt's own portability shim
		// (QOpenGLShaderProgram::addShaderFromSourceCode, qopenglshaderprogram.cpp) only
		// strips highp/mediump/lowp qualifiers for DESKTOP GL; it injects no default
		// precision statement for ES, so nothing upstream of this covers the gap either.
		// Making it explicit (highp, matching desktop GLSL's implicit full-float
		// precision) costs nothing on a lenient driver and is the only thing that can
		// prevent an outright compile failure on a strict one - not yet verified against
		// real hardware beyond the Adreno 610 already confirmed working, since none of the
		// other two reference devices (CLAUDE.md §14.2) exist yet.
		defines += "precision highp float;\nprecision highp int;\n";
	#endif

		// Add UvRect & TexRepeat uniform
		if (numSamplers > 0)
		{
			AddUniform("_uUvRect", "vec4", true, true, numSamplers);
			AddUniform("_uTexRepeat", "int", true, true, numSamplers);
			defines += "uniform vec4[" + NumStr(numSamplers) + "] _uUvRect;\n";
			defines += "uniform int[" + NumStr(numSamplers) + "] _uTexRepeat;\n";
		}

		// Compile
		vsCode = defines + vsCode;
		fsCode = defines + fsCode;

		program = new QOpenGLShaderProgram;
		if (!program->addShaderFromSourceCode(QOpenGLShader::Vertex, vsCode))
		{
			WARNING("Loading " + name + " vertex shader failed\n\t" + program->log());
			deleteAndReset(program);
			return;
		}

		if (!program->addShaderFromSourceCode(QOpenGLShader::Fragment, fsCode))
		{
			WARNING("Loading " + name + " fragment shader failed\n\t" + program->log());
			deleteAndReset(program);
			return;
		}

		// Find uniform locations
		if (program->bind())
		{
			for (IntType i = 0; i < numUniforms; i++)
				if (uniforms[i].isStatic)
					uniforms[i].glLocation = program->uniformLocation(uniforms[i].name);

			for (StringType name : samplerNameMap.keys())
				samplerState[samplerNameMap[name]].glLocation = uniforms[uniformNameMap[name]].glLocation;

			for (IntType m = 0; m < 6; m++)
			{
				QString name = matrixUniformName[m];
				if (matrixState[m].active)
					matrixState[m].uniform.glLocation = uniforms[uniformNameMap[name]].glLocation;
			}
		}
		else
		{
			WARNING("Linking " + name + " shader failed\n\t" + program->log());
			deleteAndReset(program);
			return;
		}

		// Store attribute locations
		switch (vertexFormat)
		{
			case PRIMITIVE:
				attributeLocation[0] = program->attributeLocation("in_Position");
				attributeLocation[1] = program->attributeLocation("in_Colour");
				attributeLocation[2] = program->attributeLocation("in_TextureCoord");
				break;

			case VERTEX_BUFFER:
				attributeLocation[0] = program->attributeLocation("in_Position");
				attributeLocation[1] = program->attributeLocation("_aNormal");
				attributeLocation[2] = program->attributeLocation("_aColor");
				attributeLocation[3] = program->attributeLocation("in_TextureCoord");
				attributeLocation[4] = program->attributeLocation("_aData");
				attributeLocation[5] = program->attributeLocation("_aTangent");
				break;

			case WORLD:
				attributeLocation[0] = program->attributeLocation("in_Pos");
				attributeLocation[1] = program->attributeLocation("in_Data");
				break;

			default:
				WARNING("Unknown vertex format");
		}

		// Create buffers for batching
		if (useBatching)
		{
			// Create batch buffer
			batchBufferData = new char[batchBufferSize];

			// Create SSBO and initialize
			GFX->glGenBuffers(1, &glSsboId);
			GFX->glBindBuffer(GL_SHADER_STORAGE_BUFFER, glSsboId);
			GFX->glBufferData(GL_SHADER_STORAGE_BUFFER, batchBufferSize, batchBufferData, GL_DYNAMIC_COPY);
			GFX->glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
			GL_CHECK_ERROR();

			// Get block index (glGetProgramResourceIndex exists in ES 3.1 via QOpenGLExtraFunctions,
			// unlike glShaderStorageBlockBinding - no gl43Core needed here, see CLAUDE.md §5.1.1)
			glSsboBlockIndex = GFX->glGetProgramResourceIndex(program->programId(), GL_SHADER_STORAGE_BLOCK, "_ssbo");
		}

		program->release();
	}
}
#endif