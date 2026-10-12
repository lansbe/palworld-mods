#include "lua_bridge.hpp"
#include <stdexcept>

namespace pal::script {
using namespace engine;
namespace {
int enumerate(lua_State* state) {
    auto* value = object(state, 1);
    if (!value || objectName(read<void*>(value, 16)) != "Enum") throw std::runtime_error("An engine enum is required");
    static auto getName = symbols().get<Name (*)(void*, int)>("__ZNK5UEnum14GetNameByIndexEi");
    static auto getValue = symbols().get<int64_t (*)(void*, Name, int)>("__ZNK5UEnum14GetValueByNameE5FName15EGetByNameFlags");
    if (!getName || !getValue) throw std::runtime_error("Enum reflection is unavailable");
    lua_newtable(state);
    for (int index = 0; index < 4096; ++index) {
        auto name = getName(value, index);
        if (!name.value) break;
        lua_newtable(state);
        lua_pushstring(state, text(name).c_str()); lua_setfield(state, -2, "name");
        lua_pushinteger(state, getValue(value, name, 0)); lua_setfield(state, -2, "value");
        lua_rawseti(state, -2, index + 1);
    }
    return 1;
}
int safe(lua_State* state) {
    try { return enumerate(state); }
    catch (const std::exception& error) { lua_pushstring(state, error.what()); }
    return lua_error(state);
}
}
void bindEnums(lua_State* state) {
    lua_getglobal(state, "Engine"); lua_pushcfunction(state, safe); lua_setfield(state, -2, "enum"); lua_pop(state, 1);
}
}
