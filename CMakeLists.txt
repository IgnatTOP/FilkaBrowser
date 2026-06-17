cmake_minimum_required(VERSION 3.21)

project(Filka
    VERSION 3.2.1
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
