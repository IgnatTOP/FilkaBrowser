#pragma once

#include <cstddef>
#include <cstdint>

extern "C" {

struct FilkaAdBlockEngine;

struct FilkaAdBlockDecision {
    bool matched;
    bool blocked;
    bool important;
    bool redirected;
    bool rewritten;
};

FilkaAdBlockEngine *filka_adblock_engine_new(const std::uint8_t *rules, std::size_t rulesLen);
void filka_adblock_engine_free(FilkaAdBlockEngine *engine);
std::size_t filka_adblock_engine_rule_count(const FilkaAdBlockEngine *engine);
FilkaAdBlockDecision filka_adblock_check_network(const FilkaAdBlockEngine *engine,
                                                 const char *url,
                                                 const char *sourceUrl,
                                                 const char *requestType);
char *filka_adblock_cosmetic_json(const FilkaAdBlockEngine *engine, const char *url);
void filka_adblock_string_free(char *value);

}
