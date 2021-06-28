vcpkg_fail_port_install(ON_ARCH "x86" "arm" "arm64")

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apache/arrow
    REF apache-arrow-4.0.0
    SHA512 4697a32004d02a519b8a8e899ed3cd981ae3485e6d34071436051080d6c84e25ad0bc568b3e52effe0a9204756da3d6e560a2037df06d2730dccd19c6b4c8027
    HEAD_REF master
    PATCHES
        all.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        csv         ARROW_CSV
        dataset     ARROW_DATASET
        filesystem  ARROW_FILESYSTEM
        flight      ARROW_FLIGHT
        json        ARROW_JSON
        orc         ARROW_ORC
        parquet     ARROW_PARQUET
        parquet     PARQUET_REQUIRE_ENCRYPTION
        s3          ARROW_S3
)

if(VCPKG_TARGET_IS_WINDOWS OR VCPKG_TARGET_IS_UWP)
    set(MALLOC_OPTIONS -DARROW_JEMALLOC=OFF)
elseif("jemalloc" IN_LIST FEATURES)
    set(MALLOC_OPTIONS -DARROW_JEMALLOC=ON)
else()
    set(MALLOC_OPTIONS -DARROW_JEMALLOC=OFF)
endif()

if(VCPKG_TARGET_IS_WINDOWS AND ("mimalloc" IN_LIST FEATURES))
    set(MALLOC_OPTIONS ${MALLOC_OPTIONS} -DARROW_MIMALLOC=ON)
else()
    set(MALLOC_OPTIONS ${MALLOC_OPTIONS} -DARROW_MIMALLOC=OFF)
endif()

string(COMPARE EQUAL ${VCPKG_LIBRARY_LINKAGE} "dynamic" ARROW_BUILD_SHARED)
string(COMPARE EQUAL ${VCPKG_LIBRARY_LINKAGE} "static" ARROW_BUILD_STATIC)
string(COMPARE EQUAL ${VCPKG_LIBRARY_LINKAGE} "dynamic" ARROW_DEPENDENCY_USE_SHARED)

if(VCPKG_TARGET_IS_WINDOWS)
    set(THRIFT_USE_SHARED OFF)
else()
    set(THRIFT_USE_SHARED ${ARROW_DEPENDENCY_USE_SHARED})
endif()

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}/cpp
    PREFER_NINJA
    OPTIONS
        ${FEATURE_OPTIONS}
        ${MALLOC_OPTIONS}
        -DARROW_BUILD_SHARED=${ARROW_BUILD_SHARED}
        -DARROW_BUILD_STATIC=${ARROW_BUILD_STATIC}
        -DARROW_BUILD_TESTS=OFF
        -DARROW_DEPENDENCY_SOURCE=SYSTEM
        -DARROW_DEPENDENCY_USE_SHARED=${ARROW_DEPENDENCY_USE_SHARED}
        -DARROW_THRIFT_USE_SHARED=${THRIFT_USE_SHARED} 
        -DBUILD_WARNING_LEVEL=PRODUCTION
        -DARROW_WITH_BROTLI=ON                 
        -DARROW_WITH_BZ2=ON
        -DARROW_WITH_LZ4=ON
        -DARROW_WITH_SNAPPY=ON
        -DARROW_WITH_ZLIB=ON
        -DARROW_WITH_ZSTD=ON
        -DZSTD_MSVC_LIB_PREFIX=
)

vcpkg_install_cmake()

vcpkg_copy_pdbs()

if(EXISTS ${CURRENT_PACKAGES_DIR}/lib/arrow_static.lib)
    message(FATAL_ERROR "Installed lib file should be named 'arrow.lib' via patching the upstream build.")
endif()

vcpkg_fixup_cmake_targets(CONFIG_PATH lib/cmake/arrow)

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/lib/cmake)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/lib/cmake)

file(INSTALL ${SOURCE_PATH}/LICENSE.txt DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/share)
