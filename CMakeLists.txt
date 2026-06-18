cmake_minimum_required(VERSION 3.21)

project(Filka
    VERSION 3.2.4
    DESCRIPTION "Filka Browser — next-generation premium browser"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# Qt 6.8+ is required (WebEngine permission API / persistent permissions,
# modern QML / MultiEffect blur).
find_package(Qt6 6.8 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    WebEngineCore
    WebEngineQuick
    Svg
    Sql
    Network)

qt_standard_project_setup(REQUIRES 6.8)
include(CTest)

add_subdirectory(app)

if(WIN32)
    set(CPACK_GENERATOR "NSIS")
    set(CPACK_PACKAGE_NAME "Filka Browser")
    set(CPACK_PACKAGE_VENDOR "Filka")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
    set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "Filka Browser")
    set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}/package")
    if(NOT DEFINED CPACK_PACKAGE_FILE_NAME)
        set(CPACK_PACKAGE_FILE_NAME "Filka-${PROJECT_VERSION}-windows-x86_64")
    endif()

    set(CPACK_PACKAGE_EXECUTABLES "filka" "Filka Browser")
    set(CPACK_CREATE_DESKTOP_LINKS "filka")
    set(CPACK_NSIS_EXECUTABLES_DIRECTORY "bin")
    set(CPACK_NSIS_DISPLAY_NAME "Filka Browser")
    set(CPACK_NSIS_PACKAGE_NAME "Filka Browser")
    set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
    set(CPACK_NSIS_INSTALLED_ICON_NAME "bin\\\\filka.exe")
    set(CPACK_NSIS_MUI_ICON "${CMAKE_SOURCE_DIR}/app/assets/filka.ico")
    set(CPACK_NSIS_MUI_UNIICON "${CMAKE_SOURCE_DIR}/app/assets/filka.ico")
    set(CPACK_NSIS_MODIFY_PATH OFF)
    set(CPACK_VERBATIM_VARIABLES YES)

    if(EXISTS "${CMAKE_SOURCE_DIR}/LICENSE")
        set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE")
    endif()

    include(CPack)
endif()
