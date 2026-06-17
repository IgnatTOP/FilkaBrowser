import QtQml
import QtWebEngine
import Filka

// Main owns process-wide browser resources. Normal windows share one persistent
// profile; private windows get their own off-the-record profile inside
// BrowserWindow.
QtObject {
    id: root

    property var windows: []

    function activeNormalWindow() {
        for (let i = windows.length - 1; i >= 0; --i) {
            const window = windows[i]
            if (window && !window.privateMode && window.visible && window.active)
                return window
        }
        for (let i = windows.length - 1; i >= 0; --i) {
            const window = windows[i]
            if (window && !window.privateMode && window.visible)
                return window
        }
        return null
    }

    function hasPrivateWindows() {
        for (let i = 0; i < windows.length; ++i) {
            if (windows[i] && windows[i].privateMode)
                return true
        }
        return false
    }

    function handleSharedDownload(download) {
        const window = activeNormalWindow()
        if (window && window.browserView) {
            window.browserView.handleDownload(download)
            return
        }
        const name = download.downloadFileName && download.downloadFileName.length > 0
                ? download.downloadFileName : download.suggestedFileName
        DownloadModel.acceptDownload(download, AppSettings.downloadPath, name, false)
    }

    function openWindow(privateWindow) {
        const props = {
            "privateMode": privateWindow === true,
            "windowManager": root,
            "sharedProfile": privateWindow === true ? null : sharedProfile
        }
        const window = browserWindowComponent.createObject(root, props)
        if (!window) {
            console.warn("Filka: cannot open browser window")
            return
        }
        windows.push(window)
    }

    function releaseWindow(window) {
        const index = windows.indexOf(window)
        if (index >= 0)
            windows.splice(index, 1)
    }

    function closeWindow(window) {
        const wasPrivate = window.privateMode
        releaseWindow(window)
        window.visible = false
        window.destroy()
        if (wasPrivate && !hasPrivateWindows())
            DownloadModel.clearPrivateDownloads()
        if (windows.length === 0)
            Qt.quit()
    }

    property WebEngineProfile sharedProfile: WebEngineProfile {
        storageName: "filka"
        offTheRecord: false
        persistentStoragePath: AppSettings.webStoragePath()
        cachePath: AppSettings.webCachePath()
        persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
        persistentPermissionsPolicy: WebEngineProfile.StoreOnDisk
        httpCacheType: WebEngineProfile.DiskHttpCache
        httpCacheMaximumSize: 256 * 1024 * 1024
        downloadPath: AppSettings.downloadPath
        httpAcceptLanguage: Qt.locale().name.replace("_", "-")
        spellCheckEnabled: true
        onDownloadRequested: (download) => root.handleSharedDownload(download)
    }

    property Component browserWindowComponent: Component {
        BrowserWindow {}
    }

    Component.onCompleted: {
        AdBlockManager.attachProfile(sharedProfile)
        openWindow(false)
    }
}
