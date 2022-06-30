vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO edenhill/librdkafka
    REF v1.9.0
    SHA512 d7bff9ef29befa2cb35b52003f7b7da4425f284600dd268b268a36fb1b915917b26cb1a3e78da40eec78cbb12e2f745d2c1e88ac82f19d2beb38aa20b511438f
    HEAD_REF master
    PATCHES lz4.patch
)

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "static" RDKAFKA_BUILD_STATIC)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        ssl     WITH_SSL
        zlib    WITH_ZLIB
        zstd    WITH_ZSTD
        snappy  WITH_SNAPPY
)

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        -DRDKAFKA_BUILD_STATIC=${RDKAFKA_BUILD_STATIC}
        -DRDKAFKA_BUILD_EXAMPLES=OFF
        -DRDKAFKA_BUILD_TESTS=OFF
        -DWITH_BUNDLED_SSL=OFF
        ${FEATURE_OPTIONS}
    OPTIONS_DEBUG
        -DENABLE_SHAREDPTR_DEBUG=ON
        -DENABLE_DEVEL=ON
        -DENABLE_REFCNT_DEBUG=OFF
        -DENABLE_SHAREDPTR_DEBUG=ON
        -DWITHOUT_OPTIMIZATION=ON
    OPTIONS_RELEASE
        -DENABLE_SHAREDPTR_DEBUG=OFF
        -DENABLE_DEVEL=OFF
        -DENABLE_REFCNT_DEBUG=OFF
        -DENABLE_SHAREDPTR_DEBUG=OFF
        -DWITHOUT_OPTIMIZATION=OFF
)

vcpkg_cmake_install()

vcpkg_copy_pdbs()

vcpkg_cmake_config_fixup(
    PACKAGE_NAME RdKafka
    CONFIG_PATH lib/cmake/RdKafka
)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

if(VCPKG_LIBRARY_LINKAGE STREQUAL static)
    foreach(hdr rdkafka.h rdkafkacpp.h)
        vcpkg_replace_string(
            "${CURRENT_PACKAGES_DIR}/include/librdkafka/${hdr}"
            "#ifdef LIBRDKAFKA_STATICLIB"
            "#if 1 // #ifdef LIBRDKAFKA_STATICLIB"
        )
    endforeach()
endif()

# Handle copyright
configure_file("${SOURCE_PATH}/LICENSES.txt" "${CURRENT_PACKAGES_DIR}/share/${PORT}/copyright" COPYONLY)

# Install usage
configure_file("${CMAKE_CURRENT_LIST_DIR}/usage" "${CURRENT_PACKAGES_DIR}/share/${PORT}/usage" @ONLY)

vcpkg_fixup_pkgconfig()
