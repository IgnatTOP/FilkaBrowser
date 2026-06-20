.pragma library

function trimmed(text) {
    return ("" + text).trim()
}

function looksLikeUrl(text) {
    var s = trimmed(text)
    return /^[a-z][a-z0-9+.-]*:\/\//i.test(s)
        || /^(localhost|[0-9.]+)(:[0-9]+)?(\/.*)?$/i.test(s)
        || (!/\s/.test(s) && /^[^\s]+\.[^\s]{2,}/.test(s))
}

function resolve(text, appSettings) {
    var t = trimmed(text)
    if (t.length === 0)
        return ""
    if (/^[a-z][a-z0-9+.-]*:\/\//i.test(t))
        return t
    if (/^(localhost|[0-9.]+)(:[0-9]+)?(\/.*)?$/i.test(t))
        return "http://" + t
    if (!/\s/.test(t) && /^[^\s]+\.[^\s]{2,}/.test(t))
        return "https://" + t
    return appSettings.searchUrl(t)
}

function addUnique(out, seen, kind, title, url, label) {
    if (!url || seen[url])
        return false
    seen[url] = true
    out.push({ kind: kind, title: title, url: url, label: label })
    return true
}

function buildSuggestions(opts) {
    var t = trimmed(opts.text)
    if (t.length === 0)
        return []

    var appSettings = opts.appSettings
    var out = []
    var seen = {}
    var actionUrl = resolve(t, appSettings)

    if (looksLikeUrl(t))
        addUnique(out, seen, "go", t, actionUrl, opts.goLabel)
    else
        addUnique(out, seen, "search", t, actionUrl, opts.searchLabel)

    if (opts.quickLinkModel && opts.includeQuickLinks) {
        var quickLinks = opts.quickLinkModel.search(t, opts.quickLinkLimit || 4)
        for (var q = 0; q < quickLinks.length && out.length < (opts.maxCount || 9); ++q) {
            addUnique(out, seen, "quicklink", quickLinks[q].title, quickLinks[q].url,
                      quickLinks[q].host || quickLinks[q].url)
        }
    }

    if (opts.bookmarkModel) {
        var bm = opts.bookmarkModel.search(t, opts.bookmarkLimit || 3)
        for (var i = 0; i < bm.length && out.length < (opts.maxCount || 9); ++i)
            addUnique(out, seen, "bookmark", bm[i].title, bm[i].url, bm[i].url)
    }

    if (opts.historyModel) {
        var hist = opts.historyModel.search(t, opts.historyLimit || 5)
        for (var j = 0; j < hist.length && out.length < (opts.maxCount || 9); ++j)
            addUnique(out, seen, "history", hist[j].title, hist[j].url, hist[j].url)
    }

    if (opts.networkEnabled && !looksLikeUrl(t)
            && opts.netQuery === t.toLowerCase()) {
        var seenPhrase = {}
        seenPhrase[t.toLowerCase()] = true
        for (var k = 0; k < opts.netPhrases.length && out.length < (opts.maxCount || 9); ++k) {
            var p = ("" + opts.netPhrases[k])
            var key = p.toLowerCase()
            if (seenPhrase[key])
                continue
            seenPhrase[key] = true
            addUnique(out, seen, "suggest", p, appSettings.searchUrl(p), opts.suggestLabel)
        }
    }

    return out
}
