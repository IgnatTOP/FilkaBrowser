cmake_minimum_required(VERSION 3.21)

project(Filka
    VERSION 0.1.0
    DESCRIPTION "Filka Browser — next-generation premium browser"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# Qt 6.7+ is required (WebEngine + modern QML / MultiEffect blur).
find_package(Qt6 6.7 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    WebEngineQuick
    Svg
    Sql
    Network)

qt_standard_project_setup(REQUIRES 6.7)

add_subdirectory(app)
