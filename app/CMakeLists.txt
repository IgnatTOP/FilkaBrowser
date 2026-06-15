if(WIN32)
    find_program(MAGICK_CMD magick convert)
    if(MAGICK_CMD AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/logo.png")
        add_custom_command(
            OUTPUT "${CMAKE_CURRENT_SOURCE_DIR}/assets/filka.ico"
            COMMAND ${MAGICK_CMD} "${CMAKE_CURRENT_SOURCE_DIR}/assets/logo.png"
                    -define icon:auto-resize=16,32,48,64,128,256
                    "${CMAKE_CURRENT_SOURCE_DIR}/assets/filka.ico"
            DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/assets/logo.png"
            COMMENT "Generating Windows icon from logo.png"
        )
        set(FILKA_ICO "${CMAKE_CURRENT_SOURCE_DIR}/assets/filka.ico")
    endif()
endif()

qt_add_executable(filka
    src/main.cpp
    $<$<PLATFORM_ID:Windows>:filka.rc>
)

# Lucide-style SVG icon set, bundled into the QML module resources at
# qrc:/qt/qml/Filka/assets/icons/*.svg (see qml/components/Icon.qml).
file(GLOB FILKA_ICONS CONFIGURE_DEPENDS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} assets/icons/*.svg)

set_source_files_properties(qml/theme/Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/theme/Motion.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(filka
    URI Filka
    VERSION 1.0
    SOURCES
        src/browser/TabModel.h
        src/browser/TabModel.cpp
        src/workspace/WorkspaceModel.h
        src/workspace/WorkspaceModel.cpp
        src/data/HistoryModel.h
        src/data/HistoryModel.cpp
        src/data/BookmarkModel.h
        src/data/BookmarkModel.cpp
        src/data/PageTranslator.h
        src/data/PageTranslator.cpp
        src/data/AppSettings.h
        src/data/AppSettings.cpp
        src/update/UpdateChecker.h
        src/update/UpdateChecker.cpp
    QML_FILES
        qml/Main.qml
        qml/WelcomeDialog.qml
        qml/theme/Theme.qml
        qml/theme/Motion.qml
        qml/components/WindowChrome.qml
        qml/components/WindowControls.qml
        qml/components/GlassPanel.qml
        qml/components/GlassButton.qml
        qml/components/IconButton.qml
        qml/components/Icon.qml
        qml/components/AddressBar.qml
        qml/components/UpdateBanner.qml
        qml/components/SidePanel.qml
        qml/browser/BrowserView.qml
        qml/browser/TabPanel.qml
        qml/browser/TabItem.qml
        qml/browser/TabStrip.qml
        qml/browser/WebPane.qml
        qml/browser/StartPage.qml
        qml/browser/WebContextMenu.qml
        qml/browser/FindBar.qml
        qml/browser/PermissionBar.qml
        qml/browser/BookmarksBar.qml
        qml/panels/HistoryPanel.qml
        qml/panels/SettingsPanel.qml
        qml/panels/DownloadsPanel.qml
        qml/panels/TranslatorPanel.qml
        qml/workspace/WorkspaceSwitcher.qml
    RESOURCES
        ${FILKA_ICONS}
        assets/logo.png
)

target_include_directories(filka PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/browser
    ${CMAKE_CURRENT_SOURCE_DIR}/src/workspace
    ${CMAKE_CURRENT_SOURCE_DIR}/src/data
    ${CMAKE_CURRENT_SOURCE_DIR}/src/update)

target_link_libraries(filka PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::WebEngineQuick
    Qt6::Svg
    Qt6::Sql
    Qt6::Network
)

if(WIN32)
    set_target_properties(filka PROPERTIES WIN32_EXECUTABLE ON)
endif()

target_compile_definitions(filka PRIVATE
    $<$<CONFIG:Release>:QT_NO_DEBUG_OUTPUT>
)

install(TARGETS filka
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION bin)
