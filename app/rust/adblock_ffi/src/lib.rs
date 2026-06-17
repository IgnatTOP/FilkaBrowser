use adblock::blocker::BlockerResult;
use adblock::engine::Engine;
use adblock::lists::{FilterSet, ParseOptions};
use adblock::request::Request;
use serde::Serialize;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;
use std::slice;

pub struct FilkaAdBlockEngine {
    engine: Engine,
    rule_count: usize,
}

#[repr(C)]
pub struct FilkaAdBlockDecision {
    pub matched: bool,
    pub blocked: bool,
    pub important: bool,
    pub redirected: bool,
    pub rewritten: bool,
}

#[derive(Serialize)]
struct CosmeticPayload {
    hide_selectors: Vec<String>,
    procedural_actions: Vec<String>,
    injected_script: String,
    exceptions: Vec<String>,
    generichide: bool,
}

fn cstr_to_str<'a>(value: *const c_char) -> &'a str {
    if value.is_null() {
        return "";
    }
    unsafe { CStr::from_ptr(value) }.to_str().unwrap_or_default()
}

fn make_cstring(value: String) -> *mut c_char {
    CString::new(value).map_or(ptr::null_mut(), CString::into_raw)
}

fn engine_from_rules(rules: &str) -> FilkaAdBlockEngine {
    let mut set = FilterSet::new(false);
    set.add_filter_list(rules, ParseOptions::default());
    let rule_count = rules
        .lines()
        .filter(|line| {
            let trimmed = line.trim();
            !trimmed.is_empty() && !trimmed.starts_with('!') && !trimmed.starts_with('[')
        })
        .count();
    FilkaAdBlockEngine {
        engine: Engine::from_filter_set(set, true),
        rule_count,
    }
}

#[no_mangle]
pub extern "C" fn filka_adblock_engine_new(
    rules_ptr: *const u8,
    rules_len: usize,
) -> *mut FilkaAdBlockEngine {
    if rules_ptr.is_null() || rules_len == 0 {
        return Box::into_raw(Box::new(engine_from_rules("")));
    }
    let data = unsafe { slice::from_raw_parts(rules_ptr, rules_len) };
    let rules = std::str::from_utf8(data).unwrap_or_default();
    Box::into_raw(Box::new(engine_from_rules(rules)))
}

#[no_mangle]
pub extern "C" fn filka_adblock_engine_free(engine: *mut FilkaAdBlockEngine) {
    if !engine.is_null() {
        drop(unsafe { Box::from_raw(engine) });
    }
}

#[no_mangle]
pub extern "C" fn filka_adblock_engine_rule_count(engine: *const FilkaAdBlockEngine) -> usize {
    if engine.is_null() {
        return 0;
    }
    unsafe { (*engine).rule_count }
}

#[no_mangle]
pub extern "C" fn filka_adblock_check_network(
    engine: *const FilkaAdBlockEngine,
    url: *const c_char,
    source_url: *const c_char,
    request_type: *const c_char,
) -> FilkaAdBlockDecision {
    if engine.is_null() {
        return FilkaAdBlockDecision {
            matched: false,
            blocked: false,
            important: false,
            redirected: false,
            rewritten: false,
        };
    }

    let request = match Request::new(cstr_to_str(url), cstr_to_str(source_url), cstr_to_str(request_type)) {
        Ok(request) => request,
        Err(_) => {
            return FilkaAdBlockDecision {
                matched: false,
                blocked: false,
                important: false,
                redirected: false,
                rewritten: false,
            }
        }
    };
    let result: BlockerResult = unsafe { (*engine).engine.check_network_request(&request) };
    FilkaAdBlockDecision {
        matched: result.matched,
        blocked: result.matched && result.exception.is_none(),
        important: result.important,
        redirected: result.redirect.is_some(),
        rewritten: result.rewritten_url.is_some(),
    }
}

#[no_mangle]
pub extern "C" fn filka_adblock_cosmetic_json(
    engine: *const FilkaAdBlockEngine,
    url: *const c_char,
) -> *mut c_char {
    if engine.is_null() {
        return ptr::null_mut();
    }
    let resources = unsafe { (*engine).engine.url_cosmetic_resources(cstr_to_str(url)) };
    let payload = CosmeticPayload {
        hide_selectors: resources.hide_selectors.into_iter().collect(),
        procedural_actions: resources.procedural_actions.into_iter().collect(),
        injected_script: resources.injected_script,
        exceptions: resources.exceptions.into_iter().collect(),
        generichide: resources.generichide,
    };
    make_cstring(serde_json::to_string(&payload).unwrap_or_default())
}

#[no_mangle]
pub extern "C" fn filka_adblock_string_free(value: *mut c_char) {
    if !value.is_null() {
        drop(unsafe { CString::from_raw(value) });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn blocks_matching_network_rule() {
        let engine = engine_from_rules("||ads.example^");
        let request = Request::new(
            "https://ads.example/banner.js",
            "https://news.example/",
            "script",
        )
        .expect("request should parse");
        let result = engine.engine.check_network_request(&request);
        assert!(result.matched);
        assert!(result.exception.is_none());
    }

    #[test]
    fn emits_cosmetic_selectors_as_json() {
        let engine = engine_from_rules("example.com##.sponsored");
        let resources = engine.engine.url_cosmetic_resources("https://example.com/story");
        let payload = CosmeticPayload {
            hide_selectors: resources.hide_selectors.into_iter().collect(),
            procedural_actions: resources.procedural_actions.into_iter().collect(),
            injected_script: resources.injected_script,
            exceptions: resources.exceptions.into_iter().collect(),
            generichide: resources.generichide,
        };
        let json = serde_json::to_string(&payload).expect("payload should serialize");
        assert!(json.contains(".sponsored"));
    }

    #[test]
    fn bundled_supplement_blocks_known_test_gaps() {
        let engine = engine_from_rules(include_str!("../../../assets/filters/filka-default.txt"));
        let blocked_hosts = [
            "an.facebook.com",
            "click.googleanalytics.com",
            "iot-eu-logser.realme.com",
            "log.fc.yahoo.com",
            "udcm.yahoo.com",
            "analytics.query.yahoo.com",
            "appmetrica.yandex.ru",
            "config.unityads.unity3d.com",
            "auction.unityads.unity3d.com",
            "ads-api.twitter.com",
            "adserver.unityads.unity3d.com",
            "ads.pinterest.com",
            "business-api.tiktok.com",
            "ads-sg.tiktok.com",
            "ads.tiktok.com",
            "books-analytics-events.apple.com",
            "notes-analytics-events.apple.com",
            "weather-analytics-events.apple.com",
            "metrika.yandex.ru",
            "partnerads.ysm.yahoo.com",
            "ads.youtube.com",
            "webview.unityads.unity3d.com",
            "api-adservices.apple.com",
            "iot-logser.realme.com",
            "bdapi-in-ads.realmemobile.com",
            "grs.hicloud.com",
            "ads-api.tiktok.com",
            "data.mistat.xiaomi.com",
            "analyticsengine.s3.amazonaws.com",
            "analytics.s3.amazonaws.com",
            "gemini.yahoo.com",
            "tracking.rus.miui.com",
            "iadsdk.apple.com",
            "adtech.yahooinc.com",
            "adfstat.yandex.ru",
            "data.mistat.rus.xiaomi.com",
            "data.mistat.india.xiaomi.com",
        ];

        for host in blocked_hosts {
            let request = Request::new(
                &format!("https://{host}/track.js"),
                "https://adblock-tester.local/",
                "script",
            )
            .expect("request should parse");
            let result = engine.engine.check_network_request(&request);
            assert!(result.matched && result.exception.is_none(), "{host} was not blocked");
        }

        for path in ["ads.js", "pagead.js"] {
            let request = Request::new(
                &format!("https://cdn.example/{path}"),
                "https://adblock-tester.local/",
                "script",
            )
            .expect("request should parse");
            let result = engine.engine.check_network_request(&request);
            assert!(result.matched && result.exception.is_none(), "{path} was not blocked");
        }
    }
}
