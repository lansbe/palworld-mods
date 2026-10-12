#include "lua_bridge.hpp"
#include "transport.hpp"
#include "embedded.hpp"
#include "events.hpp"
#include <cstdio>
#include <cstdlib>
#include <string>

namespace pal::script {
namespace {
lua_State* state = nullptr;
bool attempted = false;
bool failed = false;
int traceback(lua_State* lua) {
    const char* error = lua_tostring(lua, 1);
    luaL_traceback(lua, lua, error ? error : "Unknown Lua error", 1); return 1;
}
int log(lua_State* lua) {
    for (int i = 1; i <= lua_gettop(lua); ++i) {
        size_t length = 0; const char* value = luaL_tolstring(lua, i, &length);
        const size_t limit = length >= 12 && std::strncmp(value, "[PalModsIPC]", 12) == 0 ? 1048600 : 16384;
        std::fwrite(value, 1, std::min(length, limit), stderr); lua_pop(lua, 1);
        std::fputc(i == lua_gettop(lua) ? '\n' : '\t', stderr);
    }
    return 0;
}
void report() {
    std::fprintf(stderr, "[PalMods] Script error: %s\n", lua_tostring(state, -1)); lua_pop(state, 1);
}
void start() {
    attempted = true;
    state = luaL_newstate(); luaL_openlibs(state); bind(state); bindJson(state); bindInput(state); bindEnums(state);
    lua_pushcfunction(state, log); lua_setglobal(state, "print");
    lua_getglobal(state, "package"); lua_getfield(state, -1, "preload");
    for (const auto& module : embeddedModules) {
        if (luaL_loadbuffer(state, module.source, std::strlen(module.source), module.name)) {
            report(); failed = true; break;
        }
        lua_setfield(state, -2, module.name);
    }
    lua_settop(state, 0);
    pal::transport::start(); pal::events::attach();
    lua_pushcfunction(state, traceback);
    lua_getglobal(state, "require"); lua_pushliteral(state, "main");
    if (lua_pcall(state, 1, 0, 1)) { report(); failed = true; }
    lua_settop(state, 0);
#ifdef PALMODS_DEVELOPMENT
    lua_getglobal(state, "require"); lua_pushliteral(state, "development");
    if (lua_pcall(state, 1, 0, 0)) { report(); failed = true; }
    lua_settop(state, 0);
#endif
}
}
void tick(float delta) {
    if (!attempted) start();
    if (failed || !state) return;
    lua_pushcfunction(state, traceback);
    lua_getglobal(state, "runtime_tick");
    if (lua_isfunction(state, -1)) {
        lua_pushnumber(state, delta);
        if (lua_pcall(state, 1, 0, 1)) report();
    }
    lua_settop(state, 0);
#ifdef PALMODS_DEVELOPMENT
    lua_getglobal(state, "require"); lua_pushliteral(state, "development");
    if (lua_pcall(state, 1, 0, 0)) { report(); failed = true; }
    lua_settop(state, 0);
#endif
}
}
