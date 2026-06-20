set(FILKA_WINDOWS_RC)
if(WIN32)
    set(FILKA_ICON_FILE "${CMAKE_CURRENT_BINARY_DIR}/assets/filka.ico")
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/filka.ico")
        add_custom_command(
            OUTPUT "${FILKA_ICON_FILE}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/assets"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${CMAKE_CURRENT_SOURCE_DIR}/assets/filka.ico"
                    "${FILKA_ICON_FILE}"
            DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/assets/filka.ico"
            COMMENT "Copying Windows icon")
    else()
        find_program(MAGICK_CMD NAMES magick convert)
    endif()
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/filka.ico" AND MAGICK_CMD AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/logo.png")
        add_custom_command(
            OUTPUT "${FILKA_ICON_FILE}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/assets"
            COMMAND ${MAGICK_CMD} "${CMAKE_CURRENT_SOURCE_DIR}/assets/logo.png"
                    -define icon:auto-resize=16,32,48,64,128,256
                    "${FILKA_ICON_FILE}"
            DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/assets/logo.png"
            COMMENT "Generating Windows icon from logo.png"
        )
    elseif(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/filka.ico")
        message(FATAL_ERROR "Windows builds need ImageMagick (magick/convert) or app/assets/filka.ico")
    endif()
    set(FILKA_ICON_PATH "${FILKA_ICON_FILE}")
    set(FILKA_VERSION_TWEAK 0)
    set(FILKA_WINDOWS_RC "${CMAKE_CURRENT_BINARY_DIR}/filka.rc")
    configure_file("${CMAKE_CURRENT_SOURCE_DIR}/filka.rc.in" "${FILKA_WINDOWS_RC}" @ONLY)
    set_source_files_properties("${FILKA_WINDOWS_RC}" PROPERTIES OBJECT_DEPENDS "${FILKA_ICON_FILE}")
endif()

qt_add_executable(filka
    src/main.cpp
    ${FILKA_WINDOWS_RC}
)

# Lucide-style SVG icon set, bundled into the QML module resources at
# qrc:/qt/qml/Filka/assets/icons/*.svg (see qml/components/Icon.qml).
file(GLOB FILKA_ICONS CONFIGURE_DEPENDS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} assets/icons/*.svg)
file(GLOB FILKA_WALLPAPERS CONFIGURE_DEPENDS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} assets/wallpapers/*.png)
file(GLOB FILKA_FILTERS CONFIGURE_DEPENDS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} assets/filters/*.txt)
file(GLOB_RECURSE FILKA_QML_LINT_FILES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/*.qml")
list(FILTER FILKA_QML_LINT_FILES EXCLUDE REGEX
    ".*/(BrowserView|CommandPalette|DownloadPrompt|ListCard|SiteInfoPopup|StartPage|ShellState|BrowserShortcuts|NavigationBar|PremiumSidebar)\\.qml$")

find_program(CARGO_EXECUTABLE cargo REQUIRED)
set(FILKA_ADBLOCK_RUST_DIR "${CMAKE_CURRENT_SOURCE_DIR}/rust/adblock_ffi")
set(FILKA_ADBLOCK_CARGO_TARGET_DIR "${CMAKE_CURRENT_BINARY_DIR}/rust/adblock_ffi")
if(WIN32)
    set(FILKA_ADBLOCK_RUST_LIB "${FILKA_ADBLOCK_CARGO_TARGET_DIR}/release/filka_adblock_ffi.lib")
else()
    set(FILKA_ADBLOCK_RUST_LIB "${FILKA_ADBLOCK_CARGO_TARGET_DIR}/release/libfilka_adblock_ffi.a")
endif()
add_custom_command(
    OUTPUT "${FILKA_ADBLOCK_RUST_LIB}"
    COMMAND ${CMAKE_COMMAND} -E env
            CARGO_TARGET_DIR="${FILKA_ADBLOCK_CARGO_TARGET_DIR}"
            ${CARGO_EXECUTABLE} build --release --manifest-path "${FILKA_ADBLOCK_RUST_DIR}/Cargo.toml"
    DEPENDS
        "${FILKA_ADBLOCK_RUST_DIR}/Cargo.toml"
        "${FILKA_ADBLOCK_RUST_DIR}/Cargo.lock"
        "${FILKA_ADBLOCK_RUST_DIR}/src/lib.rs"
    WORKING_DIRECTORY "${FILKA_ADBLOCK_RUST_DIR}"
    COMMENT "Building Filka adblock-rust FFI")
add_custom_target(filka_adblock_ffi_build DEPENDS "${FILKA_ADBLOCK_RUST_LIB}")
add_library(filka_adblock_ffi STATIC IMPORTED GLOBAL)
set_target_properties(filka_adblock_ffi PROPERTIES IMPORTED_LOCATION "${FILKA_ADBLOCK_RUST_LIB}")
add_dependencies(filka_adblock_ffi filka_adblock_ffi_build)
if(WIN32)
    set_target_properties(filka_adblock_ffi PROPERTIES INTERFACE_LINK_LIBRARIES "ntdll")
endif()

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
        src/adblock/AdBlockFfi.h
        src/adblock/AdBlockInterceptor.h
        src/adblock/AdBlockInterceptor.cpp
        src/adblock/AdBlockManager.h
        src/adblock/AdBlockManager.cpp
        src/workspace/WorkspaceModel.h
        src/workspace/WorkspaceModel.cpp
        src/data/HistoryModel.h
        src/data/HistoryModel.cpp
        src/data/BookmarkModel.h
        src/data/BookmarkModel.cpp
        src/data/QuickLinkModel.h
        src/data/QuickLinkModel.cpp
        src/data/DownloadModel.h
        src/data/DownloadModel.cpp
        src/data/PageTranslator.h
        src/data/PageTranslator.cpp
        src/data/AppSettings.h
        src/data/AppSettings.cpp
        src/data/BrowsingData.h
        src/data/BrowsingData.cpp
        src/import/BrowserImporter.h
        src/import/BrowserImporter.cpp
        src/media/ScreenshotHelper.h
        src/media/ScreenshotHelper.cpp
        src/update/UpdateChecker.h
        src/update/UpdateChecker.cpp
    QML_FILES
        qml/Main.qml
        qml/BrowserWindow.qml
        qml/WelcomeDialog.qml
        qml/theme/Theme.qml
        qml/theme/Motion.qml
        qml/components/WindowChrome.qml
        qml/components/WindowControls.qml
        qml/components/GlassPanel.qml
        qml/components/GlassButton.qml
        qml/components/IconButton.qml
        qml/components/Icon.qml
        qml/components/Favicon.qml
        qml/components/AddressBar.qml
        qml/components/UpdateBanner.qml
        qml/components/SidePanel.qml
        qml/components/Pill.qml
        qml/components/Chip.qml
        qml/components/ToggleSwitch.qml
        qml/components/SectionLabel.qml
        qml/components/AccentSwatch.qml
        qml/components/FilkaScrollBar.qml
        qml/components/ConfirmActionButton.qml
        qml/components/UndoToast.qml
        qml/browser/BrowserView.qml
        qml/browser/ShellState.qml
        qml/browser/NavigationBar.qml
        qml/browser/PanelHost.qml
        qml/browser/BrowserShortcuts.qml
        qml/browser/WallpaperBackdrop.qml
        qml/browser/PremiumSidebar.qml
        qml/browser/CommandPalette.qml
        qml/browser/SiteInfoPopup.qml
        qml/browser/DownloadPrompt.qml
        qml/browser/MediaControlsPopover.qml
        qml/browser/PictureInPictureWindow.qml
        qml/browser/ScreenshotOverlay.qml
        qml/browser/ScreenshotPrompt.qml
        qml/browser/TabPanel.qml
        qml/browser/TabItem.qml
        qml/browser/TabSearchOverlay.qml
        qml/browser/TabStrip.qml
        qml/browser/WebPane.qml
        qml/browser/StartPage.qml
        qml/browser/ListCard.qml
        qml/browser/WebContextMenu.qml
        qml/browser/TabContextMenu.qml
        qml/browser/FindBar.qml
        qml/browser/ImportDialog.qml
        qml/browser/PermissionBar.qml
        qml/browser/BookmarksBar.qml
        qml/panels/HistoryPanel.qml
        qml/panels/BookmarksPanel.qml
        qml/panels/SettingsPanel.qml
        qml/panels/DownloadsPanel.qml
        qml/panels/TranslatorPanel.qml
        qml/panels/TranslatorPopover.qml
        qml/workspace/WorkspaceSwitcher.qml
    RESOURCES
        ${FILKA_ICONS}
        ${FILKA_WALLPAPERS}
        ${FILKA_FILTERS}
        assets/logo.png
)

target_include_directories(filka PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/adblock
    ${CMAKE_CURRENT_SOURCE_DIR}/src/browser
    ${CMAKE_CURRENT_SOURCE_DIR}/src/workspace
    ${CMAKE_CURRENT_SOURCE_DIR}/src/data
    ${CMAKE_CURRENT_SOURCE_DIR}/src/import
    ${CMAKE_CURRENT_SOURCE_DIR}/src/media
    ${CMAKE_CURRENT_SOURCE_DIR}/src/update)

target_link_libraries(filka PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::WebEngineCore
    Qt6::WebEngineQuick
    Qt6::Svg
    Qt6::Sql
    Qt6::Network
    filka_adblock_ffi
)

if(WIN32)
    target_link_libraries(filka PRIVATE ntdll)
endif()

if(UNIX AND NOT APPLE)
    target_link_libraries(filka PRIVATE ${CMAKE_DL_LIBS} m pthread)
endif()

target_compile_definitions(filka PRIVATE
    FILKA_VERSION="${PROJECT_VERSION}"
    $<$<CONFIG:Release>:QT_NO_DEBUG_OUTPUT>
)

if(BUILD_TESTING)
    find_package(Qt6 6.8 REQUIRED COMPONENTS Test)

    add_executable(filka_model_tests
        tests/test_tabmodel.cpp
        src/browser/TabModel.cpp
        src/browser/TabModel.h
        src/workspace/WorkspaceModel.cpp
        src/workspace/WorkspaceModel.h
        src/data/HistoryModel.cpp
        src/data/HistoryModel.h
        src/data/BookmarkModel.cpp
        src/data/BookmarkModel.h
        src/data/QuickLinkModel.cpp
        src/data/QuickLinkModel.h
    )
    target_include_directories(filka_model_tests PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/browser
        ${CMAKE_CURRENT_SOURCE_DIR}/src/workspace
        ${CMAKE_CURRENT_SOURCE_DIR}/src/data)
    target_link_libraries(filka_model_tests PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Sql
        Qt6::Test)
    add_test(NAME filka_model_tests COMMAND filka_model_tests)
endif()

find_program(QMLLINT_EXECUTABLE
    NAMES qmllint
    HINTS "${QT_HOST_PATH}/bin")
if(QMLLINT_EXECUTABLE)
    add_custom_target(filka_qml_lint
        COMMAND ${QMLLINT_EXECUTABLE}
                -I "${CMAKE_CURRENT_BINARY_DIR}"
                -I "${CMAKE_CURRENT_SOURCE_DIR}/qml"
                ${FILKA_QML_LINT_FILES}
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        COMMENT "Running qmllint for Filka QML")
else()
    add_custom_target(filka_qml_lint
        COMMAND ${CMAKE_COMMAND} -E echo "qmllint was not found in the active Qt installation"
        COMMAND ${CMAKE_COMMAND} -E false
        COMMENT "qmllint unavailable")
endif()

install(TARGETS filka
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION bin)

if(WIN32)
    qt_generate_deploy_qml_app_script(
        TARGET filka
        OUTPUT_SCRIPT FILKA_DEPLOY_SCRIPT
        NO_UNSUPPORTED_PLATFORM_ERROR)
    install(SCRIPT ${FILKA_DEPLOY_SCRIPT})
endif()
