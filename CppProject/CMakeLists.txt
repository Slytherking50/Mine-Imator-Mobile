cmake_minimum_required(VERSION 3.18)

# Toolchain-affecting settings established before project()
if(CMAKE_HOST_WIN32)
	set(CMAKE_CONFIGURATION_TYPES "Debug;RelWithDebInfo;Release" CACHE STRING "Supported build configurations" FORCE)
	cmake_policy(SET CMP0091 NEW)
endif()

if(CMAKE_HOST_APPLE)
	if(NOT DEFINED CMAKE_OSX_ARCHITECTURES OR CMAKE_OSX_ARCHITECTURES STREQUAL "")
		execute_process(COMMAND uname -m
			OUTPUT_VARIABLE CMAKE_OSX_ARCHITECTURES
			OUTPUT_STRIP_TRAILING_WHITESPACE)
	endif()
	if(NOT CMAKE_OSX_ARCHITECTURES MATCHES "^(x86_64|arm64)$")
		message(FATAL_ERROR
			"CMAKE_OSX_ARCHITECTURES must contain one architecture: x86_64 or arm64")
	endif()
	set(CMAKE_OSX_ARCHITECTURES "${CMAKE_OSX_ARCHITECTURES}"
		CACHE STRING "macOS target architecture" FORCE)
	if(NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET OR CMAKE_OSX_DEPLOYMENT_TARGET STREQUAL "")
		if(CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
			set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0")
		else()
			set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15")
		endif()
	endif()
	if(CMAKE_OSX_ARCHITECTURES STREQUAL "arm64"
		AND CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS "11.0")
		message(FATAL_ERROR "arm64 requires CMAKE_OSX_DEPLOYMENT_TARGET 11.0 or newer")
	endif()
	set(CMAKE_OSX_DEPLOYMENT_TARGET "${CMAKE_OSX_DEPLOYMENT_TARGET}"
		CACHE STRING "Minimum supported macOS version" FORCE)
endif()

if(CMAKE_HOST_UNIX AND NOT CMAKE_HOST_APPLE)
	set(CMAKE_C_COMPILER "/usr/bin/clang" CACHE FILEPATH "Linux C compiler" FORCE)
	set(CMAKE_CXX_COMPILER "/usr/bin/clang++" CACHE FILEPATH "Linux C++ compiler" FORCE)
endif()

project(Mine-imator LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CLANG21_WARNING_SUPPRESSIONS)
set_property(GLOBAL PROPERTY USE_FOLDERS ON)
get_filename_component(REPO_DIR
	"${CMAKE_CURRENT_SOURCE_DIR}/.."
	ABSOLUTE
)

# Third-party source and Qt installation roots
if(NOT DEFINED DEV_DIR)
	if(DEFINED ENV{DEV_DIR})
		set(DEV_DIR "$ENV{DEV_DIR}" CACHE PATH "Third-party development directory")
	else()
		message(FATAL_ERROR "DEV_DIR is not set. Define the environment variable or pass -DDEV_DIR=<path>.")
	endif()
endif()
file(TO_CMAKE_PATH "${DEV_DIR}" DEV_DIR)
message(STATUS "DEV_DIR = ${DEV_DIR}")

set(QT_BASE_DIR "${DEV_DIR}/Qt/5.15.19")
if(ANDROID)
	set(QT_INSTALL_DIR "${QT_BASE_DIR}/install-android")
else()
	set(QT_INSTALL_DIR "${QT_BASE_DIR}/install")
endif()
set(QT_SOURCE_DIR "${QT_BASE_DIR}/qt5")
set(LIBZIP_SOURCE_DIR "${DEV_DIR}/Libzip/libzip-1.11.4")
set(FFMPEG_SOURCE_DIR "${DEV_DIR}/FFmpeg/ffmpeg-5.1.10")
set(OPENAL_SOURCE_DIR "${DEV_DIR}/OpenAL/openal-soft-1.24.3")

set(ASSET_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Asset")
set(GM_SHADERS_DIR "${REPO_DIR}/GmProject/shaders")
set(CPPGEN_DIR "${REPO_DIR}/CppGen")
set(INSTALL_DIR "${REPO_DIR}/install")

if(WIN32 AND CMAKE_GENERATOR_PLATFORM STREQUAL "Win32")
	set(WINDOWS_ARCH "Win32")
	set(EXTERNAL_PLATFORM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/External/Win32")
	set(QT_INSTALL_DIR "${QT_BASE_DIR}-Win32/install")
	set(QT_SOURCE_DIR "${QT_BASE_DIR}-Win32/qt5")
	set(CPPGEN_EXE "${CPPGEN_DIR}/Win32/CppGen.exe")
	set(INSTALL_DIR "${REPO_DIR}/install-Win32")
elseif(WIN32)
	set(WINDOWS_ARCH "x64")
	set(EXTERNAL_PLATFORM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/External/Win64")
	set(CPPGEN_EXE "${CPPGEN_DIR}/Win64/CppGen.exe")
elseif(APPLE)
	set(EXTERNAL_PLATFORM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/External/Mac")
	set(CPPGEN_EXE "${CPPGEN_DIR}/Mac/CppGen")
	execute_process(COMMAND brew --prefix libomp
		RESULT_VARIABLE LIBOMP_RESULT
		OUTPUT_VARIABLE LIBOMP_PREFIX OUTPUT_STRIP_TRAILING_WHITESPACE)
	if(NOT LIBOMP_RESULT EQUAL 0 OR NOT EXISTS "${LIBOMP_PREFIX}/include/omp.h")
		message(FATAL_ERROR "Homebrew libomp was not found")
	endif()
	if(CMAKE_OSX_ARCHITECTURES STREQUAL "x86_64")
		set(OPENMP_RUNTIME_LIBRARY "${EXTERNAL_PLATFORM_DIR}/libomp.dylib")
		set(OPENMP_LINKED_LIBRARY "/usr/local/opt/libomp/lib/libomp.dylib")
	else()
		set(OPENMP_RUNTIME_LIBRARY "${LIBOMP_PREFIX}/lib/libomp.dylib")
		set(OPENMP_LINKED_LIBRARY "${OPENMP_RUNTIME_LIBRARY}")
	endif()
	if(NOT EXISTS "${OPENMP_RUNTIME_LIBRARY}")
		message(FATAL_ERROR "OpenMP runtime was not found at ${OPENMP_RUNTIME_LIBRARY}")
	endif()
	set(OpenMP_libomp_LIBRARY "${OPENMP_RUNTIME_LIBRARY}" CACHE FILEPATH "" FORCE)
	set(OpenMP_CXX_INCLUDE_DIR "${LIBOMP_PREFIX}/include" CACHE PATH "" FORCE)
elseif(ANDROID)
	set(EXTERNAL_PLATFORM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/External/Android")
	# CppGen runs once on the HOST during configure/build - it emits platform-agnostic
	# C++ regardless of ANDROID_ABI (verified in 0.2, research/2026-09-06-cppgen.md) - so
	# this picks the host's own CppGen binary, not an Android one (there isn't one, nor
	# does one need to exist).
	if(CMAKE_HOST_WIN32)
		set(CPPGEN_EXE "${CPPGEN_DIR}/Win64/CppGen.exe")
	elseif(CMAKE_HOST_APPLE)
		set(CPPGEN_EXE "${CPPGEN_DIR}/Mac/CppGen")
	else()
		set(CPPGEN_EXE "${CPPGEN_DIR}/Linux/CppGen")
	endif()
else()
	set(EXTERNAL_PLATFORM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/External/Linux")
	set(CPPGEN_EXE "${CPPGEN_DIR}/Linux/CppGen")
	if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 21)
		list(APPEND CLANG21_WARNING_SUPPRESSIONS -Wno-nontrivial-memcall)
	endif()
endif()

message(STATUS "CppGen location = ${CPPGEN_EXE}")
message(STATUS "External libraries = ${EXTERNAL_PLATFORM_DIR}")
message(STATUS "Qt installation = ${QT_INSTALL_DIR}")

# RelWithDebInfo configuration
if(MSVC)
	set(RELWITHDEBINFO_CXX_FLAGS "${CMAKE_CXX_FLAGS_RELEASE} /Zi")
	set(RELWITHDEBINFO_LINKER_FLAGS
		"${CMAKE_EXE_LINKER_FLAGS_RELEASE} /DEBUG:FULL /OPT:REF /OPT:ICF")
else()
	set(RELWITHDEBINFO_CXX_FLAGS "${CMAKE_CXX_FLAGS_RELEASE} -g")
	set(RELWITHDEBINFO_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
endif()
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${RELWITHDEBINFO_CXX_FLAGS}"
	CACHE STRING "C++ flags for RelWithDebInfo" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO "${RELWITHDEBINFO_LINKER_FLAGS}"
	CACHE STRING "Executable linker flags for RelWithDebInfo" FORCE)

if(ANDROID)
	# Read by Qt5AndroidSupport.cmake (auto-included via find_package(Qt5) below) to build
	# android_deployment_settings.json for androiddeployqt. minSdk=29 is the closed [GATE G1]
	# decision (CLAUDE.md §7.1.1); targetSdk=34 matches the only SDK platform installed here.
	# Must be set as cache variables BEFORE find_package(Qt5), since the module's own
	# set(... CACHE STRING ...) calls (with no FORCE) are a no-op once these already exist.
	set(ANDROID_MIN_SDK_VERSION "29" CACHE STRING "Android minimum SDK version")
	set(ANDROID_TARGET_SDK_VERSION "34" CACHE STRING "Android target SDK version")
	# Plain (non-cache) variable, read by the same module to fill "android-package-source-directory"
	set(ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Android")

	# find_package(OpenMP REQUIRED) below applies to every platform, Android included - it's
	# never had an Android-specific exclusion because nobody had run a real build on a device
	# yet to notice. NDK clang happily compiles and LINKS against OpenMP (-fopenmp=libomp),
	# but the runtime it links against (a build-time-only file inside the NDK's own clang
	# resource dir, not part of any Android system image) never gets bundled into the APK -
	# confirmed 2026-09-08 on a real device: app installed, all Qt/FFmpeg/OpenAL/zip libraries
	# loaded fine, then a hard crash (UnsatisfiedLinkError) loading our own .so specifically:
	# "library "libomp.so" not found". Fixed the same way as every other runtime dependency in
	# this file - bundle the real .so via ANDROID_EXTRA_LIBS - rather than by removing OpenMP,
	# since Mine-imator's own code relies on it being present (REQUIRED, not optional, below).
	if(CMAKE_HOST_WIN32)
		set(ANDROID_NDK_HOST_TAG "windows-x86_64")
	elseif(CMAKE_HOST_APPLE)
		set(ANDROID_NDK_HOST_TAG "darwin-x86_64")
	else()
		set(ANDROID_NDK_HOST_TAG "linux-x86_64")
	endif()
	# "aarch64" (not "${ANDROID_ABI}") because that's the NDK's own arch-folder naming under
	# its clang resource dir, and matches the only ABI this project builds (arm64-v8a).
	file(GLOB ANDROID_OPENMP_RUNTIME
		"${ANDROID_NDK}/toolchains/llvm/prebuilt/${ANDROID_NDK_HOST_TAG}/lib/clang/*/lib/linux/aarch64/libomp.so"
	)
	if(NOT ANDROID_OPENMP_RUNTIME)
		message(FATAL_ERROR "Could not find the NDK's libomp.so runtime under ${ANDROID_NDK}")
	endif()
	list(GET ANDROID_OPENMP_RUNTIME 0 ANDROID_OPENMP_RUNTIME)

	# Bundle the shared libraries built in Fase 1 point 1 (research/2026-09-08-fase1-external-
	# libraries-android.md) into the APK - androiddeployqt only picks up .so files it's told
	# about here, it doesn't scan the link line. libqtlibpng.a is static (absorbed into our own
	# .so at link time already) so it's not listed. z/GLESv3 are NDK system libraries, already
	# on the device, never need bundling.
	# libssl.so/libcrypto.so (OpenSSL 3.0.21, Android API 29, see BUILD_NOTES.md 2026-09-16):
	# QtNetwork was reconfigured with -openssl-linked against these (auto-update feature, B22)
	# and now carries a real DT_NEEDED on them - confirmed via `llvm-readobj --needed-libs` on
	# the built libQt5Network_arm64-v8a.so, which records the plain SONAME baked into our
	# OpenSSL build ("libssl.so"/"libcrypto.so"), NOT the "_arm64-v8a"-suffixed filenames Qt's
	# own build-time linker line looked for (that suffix is only how Qt's ssl.pri locates the
	# file on disk at Qt-build time via -l, unrelated to the runtime SONAME actually recorded in
	# the binary) - so these must be bundled under their plain names, same as Qt itself expects
	# to dlopen/link them on-device.
	set(ANDROID_EXTRA_LIBS
		"${EXTERNAL_PLATFORM_DIR}/libzip.so"
		"${EXTERNAL_PLATFORM_DIR}/libopenal.so"
		"${EXTERNAL_PLATFORM_DIR}/libavformat.so"
		"${EXTERNAL_PLATFORM_DIR}/libavcodec.so"
		"${EXTERNAL_PLATFORM_DIR}/libswresample.so"
		"${EXTERNAL_PLATFORM_DIR}/libswscale.so"
		"${EXTERNAL_PLATFORM_DIR}/libavutil.so"
		"${EXTERNAL_PLATFORM_DIR}/libssl.so"
		"${EXTERNAL_PLATFORM_DIR}/libcrypto.so"
		"${ANDROID_OPENMP_RUNTIME}"
	)
	# Qt5AndroidSupport.cmake (included just below, via find_package(Qt5)) does a bare
	# find_program(ANDROID_DEPLOY_QT androiddeployqt) with no HINTS - it relies entirely on
	# CMAKE_PROGRAM_PATH/the invoking process's PATH env var. androiddeployqt.exe is a HOST
	# tool that lives in install-android/bin (built there 2026-09-08 - it wasn't originally,
	# see research/2026-09-08-fase1-external-libraries-android.md), but nothing normally puts
	# that directory on PATH, so find_program silently returned ANDROID_DEPLOY_QT-NOTFOUND
	# even with the binary present on disk. CMAKE_FIND_ROOT_PATH_MODE_PROGRAM=BOTH (already
	# set for this build tree, passed on the command line same as PACKAGE=BOTH) doesn't help
	# here - that only controls whether cross-root paths are searched, not which paths are in
	# the search list to begin with.
	set(CMAKE_PROGRAM_PATH "${QT_INSTALL_DIR}/bin")
	# Same root cause again, one level down: Qt5AndroidSupport.cmake probes for
	# libQt5Core_${abi}.so via find_library(Qt5Core_${abi}_Probe Qt5Core_${abi}) to decide
	# which ABI entries go into "architectures" in the deployment JSON - CMAKE_FIND_ROOT_PATH
	# defaults to just the NDK sysroot (via the toolchain file) for cross-compiling, and
	# install-android/lib isn't under it, so every probe came back NOTFOUND even though the
	# .so genuinely exists there. Confirmed 2026-09-08: androiddeployqt failed with "No target
	# architecture defined in json file" because "architectures": {} came out empty. Appending
	# QT_INSTALL_DIR as an extra root (the standard CMake pattern for a second cross-compile
	# prefix) lets find_library's default ONLY mode see it without weakening the restriction
	# for anything else.
	list(APPEND CMAKE_FIND_ROOT_PATH "${QT_INSTALL_DIR}")
endif()

# Find Qt package
find_package(Qt5 5.15.19 EXACT CONFIG REQUIRED COMPONENTS Widgets Gui Network Core
	PATHS "${QT_INSTALL_DIR}"
	NO_DEFAULT_PATH)
set_property(GLOBAL PROPERTY AUTOGEN_SOURCE_GROUP "QtGenerated")
set_property(GLOBAL PROPERTY AUTOGEN_TARGETS_FOLDER "CMakePredefinedTargets")
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC OFF)
set(CMAKE_AUTOUIC OFF)

# Find OpenMP
find_package(OpenMP REQUIRED COMPONENTS CXX)

# Refresh Assets.cmake manifest using CppGen
set(CPPGEN_ASSET_MANIFEST "${CMAKE_CURRENT_SOURCE_DIR}/Generated/Assets.cmake")
execute_process(
	COMMAND "${CPPGEN_EXE}" "${REPO_DIR}" "${CPPGEN_DIR}/gml.json" "--assets-manifest"
	WORKING_DIRECTORY "${CPPGEN_DIR}"
	RESULT_VARIABLE CPPGEN_ASSET_MANIFEST_RESULT
	OUTPUT_VARIABLE CPPGEN_ASSET_MANIFEST_OUTPUT
	ERROR_VARIABLE CPPGEN_ASSET_MANIFEST_ERROR
)
if(NOT CPPGEN_ASSET_MANIFEST_RESULT EQUAL 0)
	message(FATAL_ERROR
		"CppGen did not create ${CPPGEN_ASSET_MANIFEST} (exit ${CPPGEN_ASSET_MANIFEST_RESULT}).\n"
		"${CPPGEN_ASSET_MANIFEST_OUTPUT}${CPPGEN_ASSET_MANIFEST_ERROR}")
endif()
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CPPGEN_ASSET_MANIFEST}")
include("${CPPGEN_ASSET_MANIFEST}")

# Reconstruct GameMaker folder hierarchy
function(add_gm_manifest_entries CATEGORY ENTRIES_VARIABLE FILES_VARIABLE RESOURCE_ENTRIES_VARIABLE ALIASES_VARIABLE)
	set(GM_FILES)
	if(RESOURCE_ENTRIES_VARIABLE)
		set(GM_RESOURCE_ENTRIES)
	endif()
	if(ALIASES_VARIABLE)
		set(GM_ALIASES)
	endif()

	foreach(GM_ENTRY IN LISTS ${ENTRIES_VARIABLE})
		string(REPLACE "|" ";" GM_ENTRY_PARTS "${GM_ENTRY}")
		list(GET GM_ENTRY_PARTS 0 GM_ENTRY_PATH)
		set(GM_ENTRY_FILE "${REPO_DIR}/${GM_ENTRY_PATH}")
		list(APPEND GM_FILES "${GM_ENTRY_FILE}")

		if(RESOURCE_ENTRIES_VARIABLE)
			list(GET GM_ENTRY_PARTS 1 GM_ENTRY_ALIAS)
			list(GET GM_ENTRY_PARTS 2 GM_ENTRY_GROUP)
			list(APPEND GM_RESOURCE_ENTRIES "${GM_ENTRY_FILE}|${GM_ENTRY_ALIAS}")
			if(ALIASES_VARIABLE)
				list(APPEND GM_ALIASES "${GM_ENTRY_ALIAS}")
			endif()
			if(CATEGORY STREQUAL "Sprites")
				get_filename_component(GM_ENTRY_DIRECTORY "${GM_ENTRY_FILE}" DIRECTORY)
				get_filename_component(GM_ENTRY_NAME "${GM_ENTRY_DIRECTORY}" NAME)
				if(GM_ENTRY_GROUP STREQUAL "")
					set(GM_ENTRY_GROUP "${GM_ENTRY_NAME}")
				else()
					set(GM_ENTRY_GROUP "${GM_ENTRY_GROUP}/${GM_ENTRY_NAME}")
				endif()
			endif()
		else()
			list(GET GM_ENTRY_PARTS 1 GM_ENTRY_GROUP)
		endif()

		set(GM_SOURCE_GROUP "GmProject/${CATEGORY}")
		if(NOT GM_ENTRY_GROUP STREQUAL "")
			string(APPEND GM_SOURCE_GROUP "/${GM_ENTRY_GROUP}")
		endif()
		source_group("${GM_SOURCE_GROUP}" FILES "${GM_ENTRY_FILE}")
	endforeach()

	set(${FILES_VARIABLE} "${GM_FILES}" PARENT_SCOPE)
	if(RESOURCE_ENTRIES_VARIABLE)
		set(${RESOURCE_ENTRIES_VARIABLE} "${GM_RESOURCE_ENTRIES}" PARENT_SCOPE)
	endif()
	if(ALIASES_VARIABLE)
		set(${ALIASES_VARIABLE} "${GM_ALIASES}" PARENT_SCOPE)
	endif()
endfunction()

add_gm_manifest_entries("Sprites" CPPGEN_SPRITE_RESOURCE_ENTRIES
	GM_SPRITE_FILES GM_SPRITE_RESOURCE_ENTRIES "")
add_gm_manifest_entries("Shaders" CPPGEN_SHADER_RESOURCE_ENTRIES
	GM_SHADER_FILES GM_SHADER_RESOURCE_ENTRIES GM_SHADER_ALIASES)
add_gm_manifest_entries("Scripts" CPPGEN_SCRIPT_ENTRIES
	GM_SCRIPT_FILES "" "")

# Combine shaders from CppProject/Asset/Shaders and GmProject/shaders
file(GLOB_RECURSE ASSET_SHADER_SOURCE_FILES CONFIGURE_DEPENDS LIST_DIRECTORIES FALSE
	"${ASSET_SOURCE_DIR}/Shaders/*.vsh"
	"${ASSET_SOURCE_DIR}/Shaders/*.fsh"
)
list(SORT ASSET_SHADER_SOURCE_FILES)
set(SHADER_FILES)
foreach(ASSET_SHADER_SOURCE_FILE IN LISTS ASSET_SHADER_SOURCE_FILES)
	get_filename_component(ASSET_SHADER_NAME "${ASSET_SHADER_SOURCE_FILE}" NAME)
	list(FIND GM_SHADER_ALIASES "Shaders/${ASSET_SHADER_NAME}" GAME_MAKER_SHADER_INDEX)
	if(GAME_MAKER_SHADER_INDEX EQUAL -1)
		list(APPEND SHADER_FILES "${ASSET_SHADER_SOURCE_FILE}")
	endif()
endforeach()

# Exclude compiled D3D bytecode from source tree
file(GLOB_RECURSE D3D_SHADER_FILES CONFIGURE_DEPENDS LIST_DIRECTORIES FALSE
	"${ASSET_SOURCE_DIR}/Shaders/*.d3d"
)
list(SORT D3D_SHADER_FILES)

# Assemble embedded
set(ASSET_RESOURCE_ENTRIES ${GM_SPRITE_RESOURCE_ENTRIES})
foreach(SHADER_FILE IN LISTS SHADER_FILES)
	get_filename_component(SHADER_NAME "${SHADER_FILE}" NAME)
	list(APPEND ASSET_RESOURCE_ENTRIES
		"${SHADER_FILE}|Shaders/${SHADER_NAME}")
endforeach()
list(APPEND ASSET_RESOURCE_ENTRIES ${GM_SHADER_RESOURCE_ENTRIES})
foreach(D3D_SHADER_FILE IN LISTS D3D_SHADER_FILES)
	file(RELATIVE_PATH D3D_SHADER_ALIAS "${ASSET_SOURCE_DIR}" "${D3D_SHADER_FILE}")
	file(TO_CMAKE_PATH "${D3D_SHADER_ALIAS}" D3D_SHADER_ALIAS)
	list(APPEND ASSET_RESOURCE_ENTRIES
		"${D3D_SHADER_FILE}|${D3D_SHADER_ALIAS}")
endforeach()

# Android only: GmProject/datafiles/Data (legacy.midata, languages, fonts, render presets,
# splash images) embedded as a Qt resource, same mechanism already proven for shaders
# (Shader.cpp's ":/Shaders/..." path) - Android has no loose Data/ folder next to the
# executable the way desktop does (CLAUDE.md §17, B-catalog, 2026-09-10: real device install
# crashed on first launch looking for legacy.midata with nothing there). Not done for
# desktop/Mac/Linux - they already have a real Data/ folder from the POST_BUILD copy/install()
# rules below, embedding it a second time here would only add dead weight to those binaries.
# data_directory_seed_android.gml (GmProject) copies these out of the resource into a real
# writable directory at startup, verified by size. Data/Libraries/ and Data/Minecraft/ are
# excluded on purpose (see KNOWN_ISSUES.md B23 - real Mojang assets must not be packaged into
# the APK, CLAUDE.md §9.4), except Minecraft/Game Base.midata and .zip (KNOWN_ISSUES.md B25,
# renamed from "placeholder" 2026-09-11 - "placeholder" read as unfinished/broken in the
# version selector, where this filename is literally what's shown), a from-scratch fallback
# resource pack so app_startup() has something to load when no real Minecraft version is
# present.
#
# Deliberately NOT CONFIGURE_DEPENDS, unlike the sprite/shader globs above (2026-09-10): that
# flag makes ninja re-run the full CMake configure step on every single build invocation to
# re-check this glob, which hung ninja outright twice in a row on this machine ("[0/2]
# Re-checking globbed directories..." never returning) - this repo lives inside a OneDrive-
# synced folder, and re-scanning ~40 files here while OneDrive's own sync/indexing was active
# on the same tree (immediately after a lot of manual find/unzip/du activity investigating
# B23) is the working theory, not confirmed further since removing the flag fixed it. Trade-
# off accepted: adding/removing a Data/ file now needs a manual `cmake .` re-run to be picked
# up, instead of happening automatically - a rare, deliberate action, not worth re-risking the
# hang for.
if(ANDROID)
	file(GLOB_RECURSE ANDROID_DATA_FILES LIST_DIRECTORIES FALSE
		"${REPO_DIR}/GmProject/datafiles/Data/*"
	)
	list(SORT ANDROID_DATA_FILES)
	foreach(ANDROID_DATA_FILE IN LISTS ANDROID_DATA_FILES)
		file(RELATIVE_PATH ANDROID_DATA_ALIAS "${REPO_DIR}/GmProject/datafiles" "${ANDROID_DATA_FILE}")
		file(TO_CMAKE_PATH "${ANDROID_DATA_ALIAS}" ANDROID_DATA_ALIAS)
		# Data/Minecraft/Game Base.midata and .zip are the one exception let through this
		# exclusion (KNOWN_ISSUES.md B25, CLAUDE.md §17, 2026-09-10; renamed from "placeholder"
		# 2026-09-11): a from-scratch, self-authored fallback resource pack (generated PNGs -
		# flat/striped neutral-gray placeholders, no Minecraft texture data; JSON schema
		# written by hand, not copied from 1.20.2.midata) so app_startup() has SOMETHING to
		# load when Android has no real Minecraft version yet - without it the app fails to
		# start at all, not just "no blocks". Still zero Mojang assets, same as the rest of
		# this exclusion.
		if(ANDROID_DATA_ALIAS MATCHES "^Data/Minecraft/Game Base\\.(midata|zip)$")
			# fall through - explicitly allowed
		elseif(ANDROID_DATA_ALIAS MATCHES "^Data/Libraries/" OR ANDROID_DATA_ALIAS MATCHES "^Data/Minecraft/")
			continue()
		endif()
		list(APPEND ASSET_RESOURCE_ENTRIES
			"${ANDROID_DATA_FILE}|${ANDROID_DATA_ALIAS}")
	endforeach()
endif()

# Show GameMaker assets in the main project
set(IDE_ONLY_FILES ${GM_SPRITE_FILES} ${GM_SHADER_FILES} ${GM_SCRIPT_FILES} ${SHADER_FILES})
set_source_files_properties(${IDE_ONLY_FILES} PROPERTIES HEADER_FILE_ONLY TRUE)
source_group("CppProject/Asset/Shaders" FILES ${SHADER_FILES})

# Generate index file
set(QT_INDEX_FILE "${CMAKE_CURRENT_BINARY_DIR}/index.qrc")
set(INDEX_XML "<!-- Auto-generated by CMake; do not edit. -->\n<RCC>\n\t<qresource prefix=\"/\">")

foreach(ASSET_RESOURCE_ENTRY IN LISTS ASSET_RESOURCE_ENTRIES)
	string(REPLACE "|" ";" ASSET_RESOURCE_PARTS "${ASSET_RESOURCE_ENTRY}")
	list(GET ASSET_RESOURCE_PARTS 0 ASSET_FILE)
	list(GET ASSET_RESOURCE_PARTS 1 ASSET_ALIAS)
	file(TO_CMAKE_PATH "${ASSET_FILE}" ASSET_FILE_CMAKE)
	string(APPEND INDEX_XML "\n\t\t<file alias=\"${ASSET_ALIAS}\">${ASSET_FILE_CMAKE}</file>")
endforeach()
string(APPEND INDEX_XML "\n\t</qresource>\n</RCC>\n")
file(WRITE "${QT_INDEX_FILE}" "${INDEX_XML}")

qt5_add_resources(RESOURCE_SOURCES "${QT_INDEX_FILE}")

# CONFIGURE_DEPENDS retains automatic source discovery while making additions
# visible to CMake without a manual reconfigure.
file(GLOB_RECURSE PROJECT_SOURCES CONFIGURE_DEPENDS LIST_DIRECTORIES FALSE
	"${CMAKE_CURRENT_SOURCE_DIR}/*.cpp"
	"${CMAKE_CURRENT_SOURCE_DIR}/*.hpp"
)
source_group(TREE "${CMAKE_CURRENT_SOURCE_DIR}" PREFIX "CppProject" FILES ${PROJECT_SOURCES})
source_group("QtGenerated" REGULAR_EXPRESSION "[/\\\\]Qt5[^/\\\\]*_Import\\.cpp$")
source_group("QtGenerated" FILES ${RESOURCE_SOURCES})

if(WIN32)
	set(APP_ICON_RESOURCE "${CMAKE_CURRENT_SOURCE_DIR}/Asset/Icons/appicon.rc")
	source_group("CppProject/Asset/Icons" FILES "${APP_ICON_RESOURCE}")
endif()

if(ANDROID)
	# Android loads native code as a shared library via JNI (through Qt's QtActivity Java
	# shim, see Android/AndroidManifest.xml android.app.lib_name) - it is not a launchable
	# executable the way every other platform here is.
	add_library(${PROJECT_NAME} SHARED
		${PROJECT_SOURCES}
		${IDE_ONLY_FILES}
		${RESOURCE_SOURCES}
	)
else()
	add_executable(${PROJECT_NAME}
		${PROJECT_SOURCES}
		${IDE_ONLY_FILES}
		${RESOURCE_SOURCES}
		${APP_ICON_RESOURCE}
	)
endif()

if(MSVC)
	target_compile_options(${PROJECT_NAME} PRIVATE "/FI${CMAKE_CURRENT_SOURCE_DIR}/Common.hpp")
else()
	target_compile_options(${PROJECT_NAME} PRIVATE -include "${CMAKE_CURRENT_SOURCE_DIR}/Common.hpp")
endif()
if(ANDROID)
	# MovieLib.cpp includes libavcodec/avcodec.h etc, which transitively need
	# libavutil/avconfig.h - a header generated by FFmpeg's own `configure`, NOT the plain
	# FFmpeg source tree. External/Sources/libavutil/avconfig.h below is a checked-in copy of
	# that generated header, but it is the x86_64/Windows one - confirmed genuinely
	# architecture-specific 2026-09-08 (AV_HAVE_FAST_UNALIGNED is 1 there vs 0 for a real
	# aarch64 `configure` run). This Android-specific copy (from a real Android NDK
	# `configure`, External/Android/libavutil/avconfig.h) must resolve first, so it's added
	# ahead of External/Sources on the include path below.
	target_include_directories(${PROJECT_NAME} PRIVATE "${EXTERNAL_PLATFORM_DIR}")
endif()
target_include_directories(${PROJECT_NAME} PRIVATE
	"${CMAKE_CURRENT_SOURCE_DIR}"
	"${CMAKE_CURRENT_SOURCE_DIR}/External/Sources"
	"${LIBZIP_SOURCE_DIR}/lib"
	"${OPENAL_SOURCE_DIR}/include"
	"${QT_SOURCE_DIR}/qtbase/src/3rdparty/freetype/include"
)
if(NOT ANDROID)
	# Qt's own QtZlib headers set Z_PREFIX (see qt5/qtbase/src/3rdparty/zlib/qtpatches.diff),
	# which makes zconf.h #define every public zlib name with a z_ prefix (e.g.
	# "#define inflate z_inflate") so Qt's internal use of zlib never clashes with an app's
	# own zlib. GZIP.cpp/NBT.cpp #include <zlib.h> and call plain names like inflate() in
	# source - on desktop those get silently rewritten to z_inflate() by the macro and link
	# against Qt's z_-prefixed static lib. On Android there is no need for any of this: the
	# NDK sysroot ships a complete, unprefixed system zlib for free (usr/include/zlib.h +
	# usr/lib/.../libz.so, confirmed present 2026-09-08) - so Android is deliberately left
	# off this include path, <zlib.h> resolves to the NDK's plain header instead (no
	# Z_PREFIX, no renaming macro), and GZIP.cpp/NBT.cpp need zero source changes: the same
	# inflate() call now links straight against the NDK's plain symbol. See
	# target_link_libraries(... z) in the Android branch below.
	target_include_directories(${PROJECT_NAME} PRIVATE "${QT_INSTALL_DIR}/include/QtZlib")
endif()

if(APPLE OR ANDROID)
	# Fix FFmpeg include issue with VERSION - FFmpeg's source root has its own bare "version"
	# file (contains "5.1.10"), which a plain -I lets shadow libc++'s real standard <version>
	# header (C++17/20 feature-test macros), corrupting the whole #include <algorithm> chain
	# with unrelated-looking cascading errors ("reference to unresolved using declaration",
	# missing ptrdiff_t, etc.) down through <optional>/<atomic>/<ratio>. -idirafter makes the
	# compiler check system paths (where the real <version> lives) first. Originally found on
	# APPLE; NDK clang+libc++ hits the identical collision for the identical reason (confirmed
	# 2026-09-06 with a real Android build attempt - 20 "errors" that were really this one bug).
	target_compile_options(${PROJECT_NAME} PRIVATE
		"SHELL:-idirafter \"${FFMPEG_SOURCE_DIR}\""
	)
else()
	target_include_directories(${PROJECT_NAME} PRIVATE
		"${FFMPEG_SOURCE_DIR}"
	)
endif()

target_compile_definitions(${PROJECT_NAME} PRIVATE
	"BUILD_FOLDER=QString(\"${CMAKE_BINARY_DIR}\"\)"
	"PROJECT_NAME=\"${PROJECT_NAME}\""
	"ASSETS_DIR=\"${ASSET_SOURCE_DIR}\""
	"GM_SHADERS_DIR=\"${GM_SHADERS_DIR}\""
)
target_link_libraries(${PROJECT_NAME} PRIVATE
	OpenMP::OpenMP_CXX
)

if(WIN32)
	message(STATUS "Windows platform (${WINDOWS_ARCH})")

	# Qt and the bundled static libraries are built against the static MSVC CRT
	set_property(TARGET ${PROJECT_NAME} PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded")
	target_compile_options(${PROJECT_NAME} PRIVATE /MP /bigobj)
	target_compile_definitions(${PROJECT_NAME} PRIVATE OS_WINDOWS)
	target_compile_definitions(${PROJECT_NAME} PRIVATE
		"DEBUG_MODE=$<IF:$<CONFIG:Debug>,1,0>"
		"RELEASE_MODE=$<IF:$<CONFIG:Release>,1,0>"
	)

	target_link_libraries(${PROJECT_NAME} PRIVATE
		"${EXTERNAL_PLATFORM_DIR}/zip.lib"
		"${EXTERNAL_PLATFORM_DIR}/OpenAL32.lib"
		"${EXTERNAL_PLATFORM_DIR}/libavformat.a"
		"${EXTERNAL_PLATFORM_DIR}/libavcodec.a"
		"${EXTERNAL_PLATFORM_DIR}/libswresample.a"
		"${EXTERNAL_PLATFORM_DIR}/libswscale.a"
		"${EXTERNAL_PLATFORM_DIR}/libavutil.a"
		"${EXTERNAL_PLATFORM_DIR}/libx264.lib"
		Mf
		Mfplat
		mfuuid
		strmiids
		Avrt
		d3d11
		"$<$<CONFIG:Debug>:d3dcompiler>"
	)
	target_link_options(${PROJECT_NAME} PRIVATE
		"$<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:/IGNORE:4099>"
	)

	set_property(TARGET ${PROJECT_NAME} PROPERTY WIN32_EXECUTABLE "$<CONFIG:Release>")
	set_property(TARGET ${PROJECT_NAME} PROPERTY RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}")
	set_property(TARGET ${PROJECT_NAME} PROPERTY VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")
	set_property(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" PROPERTY VS_STARTUP_PROJECT ${PROJECT_NAME})
elseif(ANDROID)
	message(STATUS "Android platform (${ANDROID_ABI})")
	target_compile_options(${PROJECT_NAME} PRIVATE
		-Wall
		-Wno-overloaded-virtual
		-Wno-parentheses
		-Wno-reorder-ctor
		-Wno-sometimes-uninitialized
		-Wno-switch
		-Wno-unknown-pragmas
	)
	target_compile_definitions(${PROJECT_NAME} PRIVATE
		OS_UNIX
		"DEBUG_MODE=$<IF:$<CONFIG:Release>,0,1>"
		"RELEASE_MODE=$<IF:$<CONFIG:Release>,1,0>"
	)

	# NOT libx264 (B5, research/2026-09-06-b5-x264-mediacodec.md: GPL, and no encoder is
	# needed until Fase 7's AMediaCodec module exists). FFmpeg built as .so (not .a) here,
	# unlike every other platform - LGPL requires it be replaceable, which on Android means
	# a dynamically loaded library, not statically linked (see CLAUDE.md §9.1). None of these
	# exist yet (Fase 1 plan, point 1) - this link step will fail until they're built.
	target_link_libraries(${PROJECT_NAME} PRIVATE
		"${EXTERNAL_PLATFORM_DIR}/libzip.so"
		"${EXTERNAL_PLATFORM_DIR}/libopenal.so"
		"${EXTERNAL_PLATFORM_DIR}/libavformat.so"
		"${EXTERNAL_PLATFORM_DIR}/libavcodec.so"
		"${EXTERNAL_PLATFORM_DIR}/libswresample.so"
		"${EXTERNAL_PLATFORM_DIR}/libswscale.so"
		"${EXTERNAL_PLATFORM_DIR}/libavutil.so"
	)

	# GLESv3: Qt's QOpenGLFunctions inline wrappers (e.g. glDeleteFramebuffers) call straight
	# through to the real driver symbol - on desktop that's resolved transitively via Qt's own
	# link setup, but Android's ELF/.so linking needs the actual system library named
	# explicitly. The NDK splits ES2 and ES3 symbols into separate versioned libraries under
	# the API-level lib dir (confirmed in 0.3's Qt-for-Android build work) - GLESv3 covers both
	# here since it's a superset. Confirmed needed 2026-09-06 with a real Android build attempt
	# ("undefined symbol: glDeleteFramebuffers").
	target_link_libraries(${PROJECT_NAME} PRIVATE GLESv3)

	# Mine-imator's own font rendering (Asset/Font.cpp) calls FreeType directly, not through Qt
	# text APIs - this is Qt's own prebuilt FreeType for Android (same one desktop gets for
	# free via Qt5Gui's transitive link setup, which doesn't carry over to Android's ELF
	# linking the same way). Confirmed needed 2026-09-06 ("undefined symbol: FT_Init_FreeType").
	target_link_libraries(${PROJECT_NAME} PRIVATE "${QT_INSTALL_DIR}/lib/libqtfreetype_${ANDROID_ABI}.a")

	# libpng: Qt's prebuilt FreeType-for-Android also has undefined png_* symbols (colour
	# bitmap glyph support) - confirmed via llvm-nm -u on libqtfreetype_arm64-v8a.a,
	# 2026-09-08. Unlike zip/openal/FFmpeg, libpng's license (libpng/zlib-style, permissive)
	# has no LGPL "must be replaceable" requirement, so a static .a is fine here. The NDK
	# does not ship a system libpng (unlike zlib), so this is built from Qt's own bundled
	# source (qt5/qtbase/src/3rdparty/libpng - same source Qt uses for desktop, cross-
	# compiled standalone since that source only has a qmake .pro, no CMake support) via
	# C:/Dev/build-android-libpng, then copied into External/Android. Mine-imator's own
	# source never calls libpng directly - this exists solely to satisfy FreeType's link.
	target_link_libraries(${PROJECT_NAME} PRIVATE "${EXTERNAL_PLATFORM_DIR}/libqtlibpng.a")

	# libz: NDK sysroot system library (like GLESv3 above, not something we build - see the
	# NOT ANDROID guard around QtZlib in target_include_directories above). Needed both for
	# GZIP.cpp/NBT.cpp's own <zlib.h> use and transitively for Qt's prebuilt FreeType, which
	# was built against a plain zlib (undefined symbol at link time otherwise: "inflate").
	target_link_libraries(${PROJECT_NAME} PRIVATE z)
else()
	target_compile_options(${PROJECT_NAME} PRIVATE
		-Wall
		-Wno-overloaded-virtual
		-Wno-parentheses
		-Wno-reorder-ctor
		-Wno-sometimes-uninitialized
		-Wno-switch
		-Wno-unknown-pragmas
		${CLANG21_WARNING_SUPPRESSIONS}
	)
	target_compile_definitions(${PROJECT_NAME} PRIVATE
		OS_UNIX
		"DEBUG_MODE=$<IF:$<CONFIG:Release>,0,1>"
		"RELEASE_MODE=$<IF:$<CONFIG:Release>,1,0>"
	)

	# Static-library order matters to GNU-family linkers: dependants precede the
	# archives that satisfy them
	target_link_libraries(${PROJECT_NAME} PRIVATE
		"${EXTERNAL_PLATFORM_DIR}/libzip.a"
		"${EXTERNAL_PLATFORM_DIR}/libopenal.a"
		"${EXTERNAL_PLATFORM_DIR}/libavformat.a"
		"${EXTERNAL_PLATFORM_DIR}/libavcodec.a"
		"${EXTERNAL_PLATFORM_DIR}/libswresample.a"
		"${EXTERNAL_PLATFORM_DIR}/libswscale.a"
		"${EXTERNAL_PLATFORM_DIR}/libavutil.a"
		"${EXTERNAL_PLATFORM_DIR}/libx264.a"
	)

	if(APPLE)
		message(STATUS "macOS platform")
		target_compile_definitions(${PROJECT_NAME} PRIVATE OS_MAC GL_SILENCE_DEPRECATION)
		set_target_properties(${PROJECT_NAME} PROPERTIES
			CXX_VISIBILITY_PRESET hidden
			VISIBILITY_INLINES_HIDDEN YES
			BUILD_RPATH "@loader_path/Data/Libraries"
			INSTALL_RPATH "@loader_path/Data/Libraries"
			XCODE_GENERATE_SCHEME TRUE
		)

		find_library(ICONV_LIBRARY iconv REQUIRED)
		find_library(AUDIO_TOOLBOX_FRAMEWORK AudioToolbox REQUIRED)
		find_library(CORE_AUDIO_FRAMEWORK CoreAudio REQUIRED)
		target_link_libraries(${PROJECT_NAME} PRIVATE
			${ICONV_LIBRARY}
			${AUDIO_TOOLBOX_FRAMEWORK}
			${CORE_AUDIO_FRAMEWORK}
		)

		message(STATUS "OpenMP runtime = ${OPENMP_RUNTIME_LIBRARY}")
	else()
		message(STATUS "Linux platform")
		set_target_properties(${PROJECT_NAME} PROPERTIES
			BUILD_RPATH "$ORIGIN/Data/Libraries"
			INSTALL_RPATH "$ORIGIN/Data/Libraries"
		)
	endif()
endif()

target_link_libraries(${PROJECT_NAME} PRIVATE
	Qt5::Widgets
	Qt5::Gui
	Qt5::Network
)

# Qt5::CorePrivate exposes QtCore's private headers (QJNIObjectPrivate, QtAndroidPrivate -
# qjni_p.h/qjnihelpers_p.h under private/) - used by FileFunc.cpp's Android content:// URI
# resolver (2026-09-15). Part of QtCore itself (already built, already linked transitively via
# Widgets), NOT the separate QtAndroidExtras module confirmed missing from this Qt-Android
# install - this just adds the private include path, no rebuild/new module needed. Android-only
# since it's undocumented/unstable API, no reason to pull it into desktop builds.
if(ANDROID)
	target_link_libraries(${PROJECT_NAME} PRIVATE
		Qt5::CorePrivate
	)
endif()

# Copy datafiles from GmProjects into build folder for developer configurations.
#
# NOT done for Android - resolved differently, not a gap anymore (CLAUDE.md §17, B-catalog,
# 2026-09-10). androiddeployqt packages the APK on its own terms (gradle assets.srcDirs / Qt
# resources), ignoring both this POST_BUILD copy and the install() rules below entirely.
# Decision: folded most of Data/ into the existing .qrc alongside sprites/shaders (see the
# ANDROID_DATA_FILES block above, near ASSET_RESOURCE_ENTRIES) rather than Android's assets/+
# AssetManager - it reuses the mechanism already proven for shaders instead of a second,
# separate one. data_directory_seed_android.gml (GmProject) copies those resource files into
# a real writable directory at first run (data_directory stays a real path on Android too,
# not a Qt resource path, because two real files under it - a custom imported language and a
# downloaded Minecraft asset version - get WRITTEN to at runtime, confirmed by grep before
# choosing this design, not assumed). Data/Minecraft/ is excluded from that .qrc on purpose:
# it contains real Minecraft textures (2,845 PNGs in the bundled 1.20.2.zip, confirmed by
# inspection) that CLAUDE.md §9.4 says not to package, and David Andrei's permission covers
# his own code, not Mojang's assets - except Minecraft/Game Base.midata and .zip
# (KNOWN_ISSUES.md B25, renamed from "placeholder" 2026-09-11), a from-scratch fallback pack
# with zero Mojang content. See
# UI_DEVIATIONS.md for the resulting Android-only functional gap this leaves against §16.
# ASSETS_DIR/GM_SHADERS_DIR themselves are still absolute host build-machine paths (see
# target_compile_definitions above) - meaningless on a device regardless of this section,
# unrelated to the Data/ decision above.
if(NOT ANDROID)
set(DATAFILES_SOURCE_DIR "${REPO_DIR}/GmProject/datafiles")
if(WIN32)
	set(DATAFILES_OUTPUT_DIR "${CMAKE_BINARY_DIR}")
else()
	set(DATAFILES_OUTPUT_DIR "$<TARGET_FILE_DIR:${PROJECT_NAME}>")
endif()

add_custom_command(
	TARGET ${PROJECT_NAME} POST_BUILD
	COMMAND "${CMAKE_COMMAND}" -E
		"$<IF:$<CONFIG:Release>,echo,copy_directory>"
		"$<$<NOT:$<CONFIG:Release>>:${DATAFILES_SOURCE_DIR}>"
		"$<$<NOT:$<CONFIG:Release>>:${DATAFILES_OUTPUT_DIR}>"
	VERBATIM
)

# Installation layout
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
	set(CMAKE_INSTALL_PREFIX "${INSTALL_DIR}/Mine-imator"
		CACHE PATH "Mine-imator installation directory" FORCE)
endif()
install(TARGETS ${PROJECT_NAME}
	RUNTIME DESTINATION "."
	BUNDLE DESTINATION "."
)
install(DIRECTORY
	"${DATAFILES_SOURCE_DIR}/Data"
	"${DATAFILES_SOURCE_DIR}/Particles"
	"${DATAFILES_SOURCE_DIR}/Schematics"
	DESTINATION "."
	PATTERN "Libraries" EXCLUDE
)
install(DIRECTORY DESTINATION "Skins")

if(WIN32)
	install(FILES "${EXTERNAL_PLATFORM_DIR}/vcomp140.dll" DESTINATION ".")
	install(DIRECTORY DESTINATION "Projects")
elseif(APPLE)
	install(FILES "${OPENMP_RUNTIME_LIBRARY}" DESTINATION "Data/Libraries" RENAME "libomp.dylib")
	set(OPENMP_INSTALLED_EXECUTABLE "\${CMAKE_INSTALL_PREFIX}/Mine-imator")
	install(CODE
		"execute_process(
			COMMAND \"${CMAKE_INSTALL_NAME_TOOL}\"
				-change
				\"${OPENMP_LINKED_LIBRARY}\"
				\"@executable_path/Data/Libraries/libomp.dylib\"
				\"${OPENMP_INSTALLED_EXECUTABLE}\"
				RESULT_VARIABLE OPENMP_PATCH_RESULT
		)
		if(NOT OPENMP_PATCH_RESULT EQUAL 0)
			message(FATAL_ERROR \"Could not patch the installed OpenMP library path\")
		endif()"
	)
else()
	install(DIRECTORY "${EXTERNAL_PLATFORM_DIR}/" DESTINATION "Data/Libraries"
		FILES_MATCHING PATTERN "*.so*"
	)
endif()
endif() # NOT ANDROID (datafiles copy + install layout)

# Create CppGen shortcut in IDE
if(CMAKE_GENERATOR STREQUAL "Xcode")
	add_custom_target(CppGen)

	set_target_properties(CppGen PROPERTIES
		XCODE_GENERATE_SCHEME TRUE
		XCODE_SCHEME_EXECUTABLE "${CPPGEN_EXE}"
		XCODE_SCHEME_ARGUMENTS
			"${REPO_DIR};${CPPGEN_DIR}/gml.json"
		XCODE_SCHEME_WORKING_DIRECTORY "${CPPGEN_DIR}"
	)
else()
	add_custom_target(CppGen
		COMMAND "${CPPGEN_EXE}" "${REPO_DIR}" "${CPPGEN_DIR}/gml.json"
		WORKING_DIRECTORY "${CPPGEN_DIR}"
		COMMENT "Running CppGen"
		VERBATIM
		USES_TERMINAL
	)
endif()