#include "lua_bridge.hpp"
#include <stdexcept>

namespace pal::script {
namespace {
struct OwnedStructure {
    engine::Handle schema;
    void* data = nullptr;
    bool initialized = false;
};
using Lifecycle = void (*)(void*, void*, int);
int collect(lua_State* state) {
    auto* value = static_cast<OwnedStructure*>(luaL_checkudata(state, 1, "pal.engine.structure"));
    auto destroy = engine::symbols().get<Lifecycle>("__ZNK13UScriptStruct13DestroyStructEPvi");
    if (value->initialized && value->schema.get() && destroy) destroy(value->schema.get(), value->data, 1);
    engine::release(value->data); value->data = nullptr; value->initialized = false;
    return 0;
}
}
void copyStructure(void* schema, void* destination, const void* source) {
    using Copy = void (*)(void*, void*, const void*, int);
    static auto copy = engine::symbols().get<Copy>("__ZNK13UScriptStruct16CopyScriptStructEPvPKvi");
    if (!copy || !engine::Handle(schema).get()) throw std::runtime_error("Structure copy is unavailable");
    copy(schema, destination, source, 1);
}
void pushOpaqueStructure(lua_State* state, void* schema, void* data, size_t size) {
    if (!size || size > 65536) throw std::runtime_error("Invalid opaque structure size");
    static auto initialize = engine::symbols().get<Lifecycle>("__ZNK13UScriptStruct16InitializeStructEPvi");
    if (!initialize) throw std::runtime_error("Structure initialization is unavailable");
    if (luaL_newmetatable(state, "pal.engine.structure")) {
        lua_pushcfunction(state, collect); lua_setfield(state, -2, "__gc");
        lua_pushliteral(state, "owned engine structure"); lua_setfield(state, -2, "__metatable");
    }
    lua_pop(state, 1);
    auto* value = static_cast<OwnedStructure*>(lua_newuserdatauv(state, sizeof(OwnedStructure), 0));
    new (value) OwnedStructure{engine::Handle(schema), engine::allocate(size), false};
    luaL_setmetatable(state, "pal.engine.structure");
    initialize(schema, value->data, 1); value->initialized = true;
    copyStructure(schema, value->data, data);
}
bool copyOpaqueStructure(lua_State* state, int index, void* schema, void* destination) {
    auto* source = static_cast<OwnedStructure*>(luaL_testudata(state, index, "pal.engine.structure"));
    if (!source) return false;
    if (source->schema.get() != schema || !source->initialized) throw std::runtime_error("Structure types differ");
    copyStructure(schema, destination, source->data); return true;
}
}
