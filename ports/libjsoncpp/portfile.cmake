# Common Ambient Variables:
#   CURRENT_BUILDTREES_DIR    = ${VCPKG_ROOT_DIR}\buildtrees\${PORT}
#   CURRENT_PACKAGES_DIR      = ${VCPKG_ROOT_DIR}\packages\${PORT}_${TARGET_TRIPLET}
#   CURRENT_PORT_DIR          = ${VCPKG_ROOT_DIR}\ports\${PORT}
#   PORT                      = current port name (zlib, etc)
#   TARGET_TRIPLET            = current triplet (x86-windows, x64-windows-static, etc)
#   VCPKG_CRT_LINKAGE         = C runtime linkage type (static, dynamic)
#   VCPKG_LIBRARY_LINKAGE     = target library linkage type (static, dynamic)
#   VCPKG_ROOT_DIR            = <C:\path\to\current\vcpkg>
#   VCPKG_TARGET_ARCHITECTURE = target architecture (x64, x86, arm)
#

include(vcpkg_common_functions)

#vcpkg_download_distfile(ARCHIVE
 #   URLS "https://github.com/yuntong613/libjsoncpp/archive/1.0.0.tar.gz"
  #  FILENAME "libjsoncpp-1.0.0.tar.gz"
   # SHA512 0533505a8d0cfa3d815c032b27147326fcdd5d102c13e53b98e000e5991468970845377a243bd884b4dd35feea168f0897afd4f2dabb3af27947d1579abeb0ab#
#)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO yuntong613/libjsoncpp
    REF 1.0.1
    SHA512 23f3f81b397695e24a95ed57b3469cda6324176c725d91bd513e7d5e56e19aa4e4d869d62131cb2738924dfedbab45e4edc23c067e58042191b941bc3a178417
    HEAD_REF jsoncppcn
)

if (VCPKG_LIBRARY_LINKAGE STREQUAL dynamic)
    set(JSONCPP_STATIC OFF)
    set(JSONCPP_DYNAMIC ON)
else()
    set(JSONCPP_STATIC ON)
    set(JSONCPP_DYNAMIC OFF)
endif()

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    PREFER_NINJA # Disable this option if project cannot be built with Ninja
    # OPTIONS -DUSE_THIS_IN_ALL_BUILDS=1 -DUSE_THIS_TOO=2
    # OPTIONS_RELEASE -DOPTIMIZE=1
    # OPTIONS_DEBUG -DDEBUGGABLE=1
	DISABLE_PARALLEL_CONFIGURE
    OPTIONS -DJSONCPP_WITH_CMAKE_PACKAGE:BOOL=ON
            -DBUILD_STATIC_LIBS:BOOL=${JSONCPP_STATIC}
            -DBUILD_SHARED_LIBS:BOOL=${JSONCPP_DYNAMIC}
            -DJSONCPP_WITH_PKGCONFIG_SUPPORT:BOOL=OFF
            -DJSONCPP_WITH_TESTS:BOOL=OFF
)

vcpkg_install_cmake()

# Fix CMake files
vcpkg_fixup_cmake_targets(CONFIG_PATH lib/cmake/jsoncpp)

# Remove includes in debug
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)

# Handle copyright
# file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/libjsoncpp RENAME copyright)
file(COPY ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/libjsoncpp)
file(RENAME ${CURRENT_PACKAGES_DIR}/share/libjsoncpp/LICENSE ${CURRENT_PACKAGES_DIR}/share/libjsoncpp/copyright)

# Copy pdb files
vcpkg_copy_pdbs()

# Post-build test for cmake libraries
# vcpkg_test_cmake(PACKAGE_NAME libjsoncpp)
