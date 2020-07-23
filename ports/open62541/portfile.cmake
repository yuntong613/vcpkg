set(VERSION v1.1)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO open62541/open62541
 #   REF a524accc338c9611a5ec60bf595c1a587243b457 # v1.1
	REF v1.1.2
	SHA512 090f24b77211ef8e0a45c7b74de948db6ea64290fc591ae0131871119d826c8b385769ab4c1dad0f8ba663acafd7df3b4b288759623eb6f4a3fbd00ab65abedc
    HEAD_REF master
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    openssl UA_ENABLE_ENCRYPTION_OPENSSL
    mbedtls UA_ENABLE_ENCRYPTION_MBEDTLS
)

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON3_DIR "${PYTHON3}" DIRECTORY)
vcpkg_add_to_path("${PYTHON3_DIR}")

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    PREFER_NINJA
    OPTIONS
        ${FEATURE_OPTIONS}
        -DOPEN62541_VERSION=${VERSION}
    OPTIONS_DEBUG
        -DCMAKE_DEBUG_POSTFIX=d
)

vcpkg_install_cmake()
vcpkg_fixup_cmake_targets(CONFIG_PATH lib/cmake/${PORT})
vcpkg_copy_pdbs()

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/share)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/share/open62541/tools)

file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
