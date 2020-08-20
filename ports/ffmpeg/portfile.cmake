vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ffmpeg/ffmpeg
    REF n4.2
    SHA512 9fa56364696f91e2bf4287954d26f0c35b3f8aad241df3fbd3c9fc617235d8c83b28ddcac88436383b2eb273f690322e6f349e2f9c64d02f0058a4b76fa55035
    HEAD_REF master
    PATCHES
        0001-create-lib-libraries.patch
        0003-fix-windowsinclude.patch
        0004-fix-debug-build.patch
        0005-fix-libvpx-linking.patch
        0006-fix-StaticFeatures.patch
        0007-fix-lib-naming.patch
        0008-Fix-wavpack-detection.patch
        0009-Fix-fdk-detection.patch
        0010-Fix-x264-detection.patch
        0011-Fix-x265-detection.patch
        0012-Fix-ssl-110-detection.patch
)

if (${SOURCE_PATH} MATCHES " ")
    message(FATAL_ERROR "Error: ffmpeg will not build with spaces in the path. Please use a directory with no spaces")
endif()

vcpkg_find_acquire_program(YASM)
get_filename_component(YASM_EXE_PATH ${YASM} DIRECTORY)

if(VCPKG_TARGET_IS_WINDOWS)
    set(SEP ";")
    #We're assuming that if we're building for Windows we're using MSVC
    set(INCLUDE_VAR "INCLUDE")
    set(LIB_PATH_VAR "LIB")
else()
    set(SEP ":")
    set(INCLUDE_VAR "CPATH")
    set(LIB_PATH_VAR "LIBRARY_PATH")
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    set(ENV{PATH} "$ENV{PATH};${YASM_EXE_PATH}")

    set(BUILD_SCRIPT ${CMAKE_CURRENT_LIST_DIR}\\build.sh)

    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm" OR VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        vcpkg_acquire_msys(MSYS_ROOT PACKAGES perl gcc diffutils make pkg-config)
    else()
        vcpkg_acquire_msys(MSYS_ROOT PACKAGES diffutils make pkg-config)
    endif()

    set(BASH ${MSYS_ROOT}/usr/bin/bash.exe)
else()
    set(ENV{PATH} "$ENV{PATH}:${YASM_EXE_PATH}")
    set(BASH /bin/bash)
    set(BUILD_SCRIPT ${CMAKE_CURRENT_LIST_DIR}/build_linux.sh)
endif()

set(ENV{${INCLUDE_VAR}} "${CURRENT_INSTALLED_DIR}/include${SEP}$ENV{${INCLUDE_VAR}}")

set(_csc_PROJECT_PATH ffmpeg)

file(REMOVE_RECURSE ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel)

set(OPTIONS "--enable-asm --enable-yasm --disable-doc --enable-debug")
set(OPTIONS "${OPTIONS} --enable-runtime-cpudetect")

if("nonfree" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-nonfree")
endif()

if("gpl" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-gpl")
endif()

if("version3" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-version3")
endif()

if("ffmpeg" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-ffmpeg")
else()
    set(OPTIONS "${OPTIONS} --disable-ffmpeg")
endif()

if("ffplay" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-ffplay")
else()
    set(OPTIONS "${OPTIONS} --disable-ffplay")
endif()

if("ffprobe" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-ffprobe")
else()
    set(OPTIONS "${OPTIONS} --disable-ffprobe")
endif()

if("avcodec" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-avcodec")
    set(ENABLE_AVCODEC ON)
else()
    set(OPTIONS "${OPTIONS} --disable-avcodec")
    set(ENABLE_AVCODEC OFF)
endif()

if("avdevice" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-avdevice")
    set(ENABLE_AVDEVICE ON)
else()
    set(OPTIONS "${OPTIONS} --disable-avdevice")
    set(ENABLE_AVDEVICE OFF)
endif()

if("avformat" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-avformat")
    set(ENABLE_AVFORMAT ON)
else()
    set(OPTIONS "${OPTIONS} --disable-avformat")
    set(ENABLE_AVFORMAT OFF)
endif()

if("avfilter" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-avfilter")
    set(ENABLE_AVFILTER ON)
else()
    set(OPTIONS "${OPTIONS} --disable-avfilter")
    set(ENABLE_AVFILTER OFF)
endif()

if("postproc" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-postproc")
    set(ENABLE_POSTPROC ON)
else()
    set(OPTIONS "${OPTIONS} --disable-postproc")
    set(ENABLE_POSTPROC OFF)
endif()

if("swresample" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-swresample")
    set(ENABLE_SWRESAMPLE ON)
else()
    set(OPTIONS "${OPTIONS} --disable-swresample")
    set(ENABLE_SWRESAMPLE OFF)
endif()

if("swscale" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-swscale")
    set(ENABLE_SWSCALE ON)
else()
    set(OPTIONS "${OPTIONS} --disable-swscale")
    set(ENABLE_SWSCALE OFF)
endif()

set(ENABLE_AVRESAMPLE OFF)
if("avresample" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-avresample")
    set(ENABLE_AVRESAMPLE ON)
endif()

if("avisynthplus" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-avisynth")
else()
    set(OPTIONS "${OPTIONS} --disable-avisynth")
endif()

set(STATIC_LINKAGE OFF)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
set(STATIC_LINKAGE ON)
endif()

set(ENABLE_BZIP2 OFF)
if("bzip2" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-bzlib")
    set(ENABLE_BZIP2 ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-bzlib")
endif()

set(ENABLE_ICONV OFF)
if("iconv" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-iconv")
    set(ENABLE_ICONV ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-iconv")
endif()

set(ENABLE_FDKAAC OFF)
if("fdk-aac" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libfdk-aac")
    set(ENABLE_FDKAAC ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-libfdk-aac")
endif()

set(ENABLE_LZMA OFF)
if("lzma" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-lzma")
    set(ENABLE_LZMA ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-lzma")
endif()

set(ENABLE_LAME OFF)
if("mp3lame" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libmp3lame")
    set(ENABLE_LAME ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-libmp3lame")
endif()

if("nvcodec" IN_LIST FEATURES)
    #Note: the --enable-cuda option does not actually require the cuda sdk or toolset port dependency as ffmpeg uses runtime detection and dynamic loading
    set(OPTIONS "${OPTIONS} --enable-cuda --enable-nvenc --enable-nvdec --enable-cuvid")
else()
    set(OPTIONS "${OPTIONS} --disable-cuda --disable-nvenc --disable-nvdec  --disable-cuvid")
endif()

set(ENABLE_OPENCL OFF)
if("opencl" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-opencl")
    set(ENABLE_OPENCL ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-opencl")
endif()

set(ENABLE_OPENSSL OFF)
if("openssl" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-openssl")
    set(ENABLE_OPENSSL ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-openssl")
endif()

set(ENABLE_OPUS OFF)
if("opus" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libopus")
    set(ENABLE_OPUS ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-libopus")
endif()

set(ENABLE_SDL2 OFF)
if("sdl2" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-sdl2")
    set(ENABLE_SDL2 ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-sdl2")
endif()

set(ENABLE_SNAPPY OFF)
if("snappy" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libsnappy")
    set(ENABLE_SNAPPY ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-libsnappy")
endif()

set(ENABLE_SOXR OFF)
if("soxr" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libsoxr")
    set(ENABLE_SOXR ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-libsoxr")
endif()

set(ENABLE_SPEEX OFF)
if("speex" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libspeex")
    set(ENABLE_SPEEX ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-libspeex")
endif()

set(ENABLE_THEORA OFF)
if("theora" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libtheora")
    set(ENABLE_THEORA ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-libtheora")
endif()

set(ENABLE_VORBIS OFF)
if("vorbis" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libvorbis")
    set(ENABLE_VORBIS ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-libvorbis")
endif()

set(ENABLE_VPX OFF)
if("vpx" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libvpx")
    set(ENABLE_VPX ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-libvpx")
endif()

set(ENABLE_WAVPACK OFF)
if("wavpack" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libwavpack")
    set(ENABLE_WAVPACK ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-libwavpack")
endif()

set(ENABLE_X264 OFF)
if("x264" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libx264")
    set(ENABLE_X264 ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-libx264")
endif()

set(ENABLE_X265 OFF)
if("x265" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libx265")
    set(ENABLE_X265 ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-libx265")
endif()

set(ENABLE_ZLIB OFF)
if("zlib" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-zlib")
    set(ENABLE_ZLIB ${STATIC_LINKAGE})
else()
    set(OPTIONS "${OPTIONS} --disable-zlib")
endif()

if (VCPKG_TARGET_IS_OSX)
    set(OPTIONS "${OPTIONS} --disable-vdpau") # disable vdpau in OSX
endif()

set(OPTIONS_CROSS "")

if (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm" OR VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(OPTIONS_CROSS " --enable-cross-compile --target-os=win32 --arch=${VCPKG_TARGET_ARCHITECTURE}")
    vcpkg_find_acquire_program(GASPREPROCESSOR)
    foreach(GAS_PATH ${GASPREPROCESSOR})
        get_filename_component(GAS_ITEM_PATH ${GAS_PATH} DIRECTORY)
        set(ENV{PATH} "$ENV{PATH};${GAS_ITEM_PATH}")
    endforeach(GAS_PATH)
elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
else()
    message(FATAL_ERROR "Unsupported architecture")
endif()

if(VCPKG_TARGET_IS_UWP)
    set(ENV{LIBPATH} "$ENV{LIBPATH};$ENV{_WKITS10}references\\windows.foundation.foundationcontract\\2.0.0.0\\;$ENV{_WKITS10}references\\windows.foundation.universalapicontract\\3.0.0.0\\")
    set(OPTIONS "${OPTIONS} --disable-programs")
    set(OPTIONS "${OPTIONS} --extra-cflags=-DWINAPI_FAMILY=WINAPI_FAMILY_APP --extra-cflags=-D_WIN32_WINNT=0x0A00")
    set(OPTIONS_CROSS " --enable-cross-compile --target-os=win32 --arch=${VCPKG_TARGET_ARCHITECTURE}")
endif()

set(OPTIONS_DEBUG "--debug") # Note: --disable-optimizations can't be used due to http://ffmpeg.org/pipermail/libav-user/2013-March/003945.html
set(OPTIONS_RELEASE "")

set(OPTIONS "${OPTIONS} ${OPTIONS_CROSS}")

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    set(OPTIONS "${OPTIONS} --disable-static --enable-shared")
    if (VCPKG_TARGET_IS_UWP)
        set(OPTIONS "${OPTIONS} --extra-ldflags=-APPCONTAINER --extra-ldflags=WindowsApp.lib")
    endif()
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    set(OPTIONS "${OPTIONS} --extra-cflags=-DHAVE_UNISTD_H=0")
    if(VCPKG_CRT_LINKAGE STREQUAL "dynamic")
        set(OPTIONS_DEBUG "${OPTIONS_DEBUG} --extra-cflags=-MDd --extra-cxxflags=-MDd")
        set(OPTIONS_RELEASE "${OPTIONS_RELEASE} --extra-cflags=-MD --extra-cxxflags=-MD")
    else()
        set(OPTIONS_DEBUG "${OPTIONS_DEBUG} --extra-cflags=-MTd --extra-cxxflags=-MTd")
        set(OPTIONS_RELEASE "${OPTIONS_RELEASE} --extra-cflags=-MT --extra-cxxflags=-MT")
    endif()
endif()

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    set(OPTIONS "${OPTIONS} --pkg-config-flags=--static")
endif()

set(ENV_LIB_PATH "$ENV{${LIB_PATH_VAR}}")

message(STATUS "Building Options: ${OPTIONS}")

# Release build
if (NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL release)
    message(STATUS "Building Release Options: ${OPTIONS_RELEASE}")
    set(ENV{${LIB_PATH_VAR}} "${CURRENT_INSTALLED_DIR}/lib${SEP}${ENV_LIB_PATH}")
    set(ENV{CFLAGS} "${VCPKG_C_FLAGS} ${VCPKG_C_FLAGS_RELEASE}")
    set(ENV{LDFLAGS} "${VCPKG_LINKER_FLAGS}")
    set(ENV{PKG_CONFIG_PATH} "${CURRENT_INSTALLED_DIR}/lib/pkgconfig")
    message(STATUS "Building ${_csc_PROJECT_PATH} for Release")
    file(MAKE_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel)
    vcpkg_execute_required_process(
        COMMAND ${BASH} --noprofile --norc "${BUILD_SCRIPT}"
            "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel" # BUILD DIR
            "${SOURCE_PATH}" # SOURCE DIR
            "${CURRENT_PACKAGES_DIR}" # PACKAGE DIR
            "${OPTIONS} ${OPTIONS_RELEASE}"
        WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel
        LOGNAME build-${TARGET_TRIPLET}-rel
    )
endif()

# Debug build
if (NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL debug)
    message(STATUS "Building Debug Options: ${OPTIONS_DEBUG}")
    set(ENV{${LIB_PATH_VAR}} "${CURRENT_INSTALLED_DIR}/debug/lib${SEP}${ENV_LIB_PATH}")
    set(ENV{CFLAGS} "${VCPKG_C_FLAGS} ${VCPKG_C_FLAGS_DEBUG}")
    set(ENV{LDFLAGS} "${VCPKG_LINKER_FLAGS}")
    set(ENV{PKG_CONFIG_PATH} "${CURRENT_INSTALLED_DIR}/debug/lib/pkgconfig")
    message(STATUS "Building ${_csc_PROJECT_PATH} for Debug")
    file(MAKE_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg)
    vcpkg_execute_required_process(
        COMMAND ${BASH} --noprofile --norc "${BUILD_SCRIPT}"
            "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg" # BUILD DIR
            "${SOURCE_PATH}" # SOURCE DIR
            "${CURRENT_PACKAGES_DIR}/debug" # PACKAGE DIR
            "${OPTIONS} ${OPTIONS_DEBUG}"
        WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg
        LOGNAME build-${TARGET_TRIPLET}-dbg
    )
endif()

file(GLOB DEF_FILES ${CURRENT_PACKAGES_DIR}/lib/*.def ${CURRENT_PACKAGES_DIR}/debug/lib/*.def)

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
    set(LIB_MACHINE_ARG /machine:ARM)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(LIB_MACHINE_ARG /machine:ARM64)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    set(LIB_MACHINE_ARG /machine:x86)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(LIB_MACHINE_ARG /machine:x64)
else()
    message(FATAL_ERROR "Unsupported target architecture")
endif()

foreach(DEF_FILE ${DEF_FILES})
    get_filename_component(DEF_FILE_DIR "${DEF_FILE}" DIRECTORY)
    get_filename_component(DEF_FILE_NAME "${DEF_FILE}" NAME)
    string(REGEX REPLACE "-[0-9]*\\.def" "${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX}" OUT_FILE_NAME "${DEF_FILE_NAME}")
    file(TO_NATIVE_PATH "${DEF_FILE}" DEF_FILE_NATIVE)
    file(TO_NATIVE_PATH "${DEF_FILE_DIR}/${OUT_FILE_NAME}" OUT_FILE_NATIVE)
    message(STATUS "Generating ${OUT_FILE_NATIVE}")
    vcpkg_execute_required_process(
        COMMAND lib.exe /def:${DEF_FILE_NATIVE} /out:${OUT_FILE_NATIVE} ${LIB_MACHINE_ARG}
        WORKING_DIRECTORY ${CURRENT_PACKAGES_DIR}
        LOGNAME libconvert-${TARGET_TRIPLET}
    )
endforeach()

# Handle tools
if (VCPKG_TARGET_IS_WINDOWS)
    file(GLOB EXP_FILES ${CURRENT_PACKAGES_DIR}/lib/*.exp ${CURRENT_PACKAGES_DIR}/debug/lib/*.exp)
    file(GLOB LIB_FILES ${CURRENT_PACKAGES_DIR}/bin/*${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX} ${CURRENT_PACKAGES_DIR}/debug/bin/*${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX})
    file(GLOB EXE_FILES_REL ${CURRENT_PACKAGES_DIR}/bin/*${VCPKG_TARGET_EXECUTABLE_SUFFIX})
    file(GLOB EXE_FILES_DBG ${CURRENT_PACKAGES_DIR}/debug/bin/*${VCPKG_TARGET_EXECUTABLE_SUFFIX})
    set(FILES_TO_REMOVE ${EXP_FILES} ${LIB_FILES} ${DEF_FILES} ${EXE_FILES_REL} ${EXE_FILES_DBG})

    if(FILES_TO_REMOVE)
        if (EXE_FILES_REL)
            file(INSTALL ${EXE_FILES_REL} DESTINATION ${CURRENT_PACKAGES_DIR}/tools/${PORT})
            vcpkg_copy_tool_dependencies(${CURRENT_PACKAGES_DIR}/tools/${PORT})
        endif()
        if (EXE_FILES_DBG)
            file(INSTALL ${EXE_FILES_DBG} DESTINATION ${CURRENT_PACKAGES_DIR}/debug/tools/${PORT})
            vcpkg_copy_tool_dependencies(${CURRENT_PACKAGES_DIR}/debug/tools/${PORT})
        endif()
        file(REMOVE ${FILES_TO_REMOVE})
    endif()
endif()

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include ${CURRENT_PACKAGES_DIR}/debug/share)

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/bin ${CURRENT_PACKAGES_DIR}/debug/bin)
endif()

vcpkg_copy_pdbs()

# Handle copyright
file(STRINGS ${CURRENT_BUILDTREES_DIR}/build-${TARGET_TRIPLET}-rel-out.log LICENSE_STRING REGEX "License: .*" LIMIT_COUNT 1)
if(${LICENSE_STRING} STREQUAL "License: LGPL version 2.1 or later")
    set(LICENSE_FILE "COPYING.LGPLv2.1")
elseif(${LICENSE_STRING} STREQUAL "License: LGPL version 3 or later")
    set(LICENSE_FILE "COPYING.LGPLv3")
elseif(${LICENSE_STRING} STREQUAL "License: GPL version 2 or later")
    set(LICENSE_FILE "COPYING.GPLv2")
elseif(${LICENSE_STRING} STREQUAL "License: GPL version 3 or later")
    set(LICENSE_FILE "COPYING.GPLv3")
elseif(${LICENSE_STRING} STREQUAL "License: nonfree and unredistributable")
    set(LICENSE_FILE "COPYING.NONFREE")
    file(WRITE ${SOURCE_PATH}/${LICENSE_FILE} ${LICENSE_STRING})
else()
    message(FATAL_ERROR "Failed to identify license (${LICENSE_STRING})")
endif()

configure_file(${CMAKE_CURRENT_LIST_DIR}/FindFFMPEG.cmake.in ${CURRENT_PACKAGES_DIR}/share/${PORT}/FindFFMPEG.cmake @ONLY)
file(COPY ${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT})
file(INSTALL ${SOURCE_PATH}/${LICENSE_FILE} DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
