#include "lua_bridge.hpp"
#include "transport.hpp"
#include "events.hpp"
#include "discovery.hpp"
#include <chrono>
#include <stdexcept>

namespace pal::script {
using namespace engine;
void* View::data() const {
    auto* pointer = owner.get();
    if (!pointer) throw std::runtime_error("Engine object is no longer alive");
    return static_cast<char*>(pointer) + offset;
}
View* view(lua_State* state, int index) {
    return static_cast<View*>(luaL_testudata(state, index, "pal.engine.view"));
}
void* object(lua_State* state, int index) {
    if (lua_isnil(state, index)) return nullptr;
    auto* value = view(state, index);
    if (!value || !value->object) throw std::runtime_error("An engine object is required");
    return value->data();
}
std::string string(lua_State* state, int index) {
    if (lua_type(state, index) != LUA_TSTRING) throw std::runtime_error("A string is required");
    size_t size = 0; auto* value = lua_tolstring(state, index, &size);
    if (size > 1048576) throw std::runtime_error("String exceeds the size limit");
    return {value, size};
}
void pushObject(lua_State* state, void* pointer) {
    Handle handle(pointer);
    if (!handle.get()) { lua_pushnil(state); return; }
    auto* result = static_cast<View*>(lua_newuserdatauv(state, sizeof(View), 0));
    new (result) View{handle, read<void*>(pointer, 16), 0, true};
    luaL_setmetatable(state, "pal.engine.view");
}
namespace {
template<int (*Operation)(lua_State*)> int safe(lua_State* state) {
    try { return Operation(state); }
    catch (const std::exception& error) { lua_pushstring(state, error.what()); }
    return lua_error(state);
}
int index(lua_State* state) {
    auto* value = view(state, 1);
    if (!value) throw std::runtime_error("Invalid engine view");
    auto key = string(state, 2);
    auto* data = value->data();
    if (value->object) {
        if (key == "id") { lua_pushinteger(state, value->owner.index); return 1; }
        if (key == "key") { lua_pushfstring(state, "%d:%d", value->owner.index, value->owner.serial); return 1; }
        if (key == "outer") { pushObject(state, read<void*>(data, 32)); return 1; }
        if (key == "name") { lua_pushstring(state, objectName(data).c_str()); return 1; }
        if (key == "path") { lua_pushstring(state, objectPath(data).c_str()); return 1; }
        if (key == "class") { pushObject(state, value->schema); return 1; }
    }
    if (auto* property = findProperty(value->schema, key)) {
        pushValue(state, property, static_cast<char*>(data) + read<int32_t>(property, 0x4c), value); return 1;
    }
    if (value->object) if (auto* function = findFunction(data, key)) {
        pushObject(state, function); lua_pushcclosure(state, invoke, 1); return 1;
    }
    lua_pushnil(state); return 1;
}
int assign(lua_State* state) {
    auto* value = view(state, 1); auto key = string(state, 2);
    if (!value) throw std::runtime_error("Invalid engine view");
    auto* property = findProperty(value->schema, key);
    if (!property) throw std::runtime_error("Unknown engine property: " + key);
    setValue(state, 3, property, static_cast<char*>(value->data()) + read<int32_t>(property, 0x4c)); return 0;
}
int findObject(lua_State* state) { pushObject(state, find(string(state, 1))); return 1; }
int findObjects(lua_State* state) {
    auto result = objects(string(state, 1)); lua_createtable(state, result.size(), 0);
    int i = 0; for (auto handle : result) { pushObject(state, handle.get()); lua_rawseti(state, -2, ++i); } return 1;
}
int constructObject(lua_State* state) {
    auto* type = object(state, 1); auto* outer = object(state, 2);
    if (!type || !outer) throw std::runtime_error("Class and outer object are required");
    pushObject(state, construct(type, outer)); return 1;
}
int isA(lua_State* state) {
    auto* instance = object(state, 1); auto wanted = name(string(state, 2)).value;
    for (auto* type = instance ? read<void*>(instance, 16) : nullptr; type; type = read<void*>(type, 0x40)) {
        if (read<Name>(type, 24).value == wanted) { lua_pushboolean(state, true); return 1; }
    }
    lua_pushboolean(state, false); return 1;
}
int valid(lua_State* state) {
    auto* value = view(state, 1); lua_pushboolean(state, value && value->owner.get()); return 1;
}
int clock(lua_State* state) {
    lua_pushnumber(state, std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count()); return 1;
}
int subscribe(lua_State* state) { pal::discovery::subscribe(string(state, 1)); return 0; }
int discoveries(lua_State* state) {
    auto changes = pal::discovery::poll(); lua_newtable(state);
    for (const auto& [name, handles] : changes) {
        lua_createtable(state, handles.size(), 0); int index = 0;
        for (const auto& handle : handles) { pushObject(state, handle.get()); lua_rawseti(state, -2, ++index); }
        lua_setfield(state, -2, name.c_str());
    }
    return 1;
}
int clicks(lua_State* state) {
    auto events = pal::events::takeClicks(); lua_createtable(state, events.size(), 0); int i = 0;
    for (const auto& handle : events) { pushObject(state, handle.get()); lua_rawseti(state, -2, ++i); }
    return 1;
}
int messages(lua_State* state) {
    auto lines = pal::transport::take(); lua_createtable(state, lines.size(), 0); int i = 0;
    for (const auto& line : lines) { lua_pushlstring(state, line.data(), line.size()); lua_rawseti(state, -2, ++i); }
    return 1;
}
int quit(lua_State*) {
    static auto fn = symbols().get<void (*)(bool)>("__ZN16FMacPlatformMisc11RequestExitEb");
    if (!fn) throw std::runtime_error("Native exit is unavailable");
    fn(false); return 0;
}
int schema(lua_State* state) {
    auto* structure = object(state, 1); if (!structure) throw std::runtime_error("A schema object is required");
    lua_newtable(state); int i = 0;
    for (auto* property : properties(structure)) {
        lua_newtable(state);
        lua_pushstring(state, text(read<Name>(property, 0x28)).c_str()); lua_setfield(state, -2, "name");
        lua_pushstring(state, propertyKind(property).c_str()); lua_setfield(state, -2, "type");
        lua_pushinteger(state, read<int32_t>(property, 0x4c)); lua_setfield(state, -2, "offset");
        lua_pushinteger(state, read<int32_t>(property, 0x38)); lua_setfield(state, -2, "size");
        lua_pushinteger(state, read<int64_t>(property, 0x40)); lua_setfield(state, -2, "flags");
        if (propertyKind(property) == "StructProperty") {
            pushObject(state, read<void*>(property, 0x78)); lua_setfield(state, -2, "structure");
        }
        lua_rawseti(state, -2, ++i);
    }
    return 1;
}
#ifdef PALMODS_DEVELOPMENT
int functions(lua_State* state) {
    auto* type = object(state, 1);
    lua_newtable(state); int count = 0;
    for (unsigned depth = 0; type && depth < 32; type = read<void*>(type, 0x40), ++depth) {
        if (!Handle(type).get()) throw std::runtime_error("Expired class schema");
        for (auto* field = read<void*>(type, 0x48); field && count < 512; field = read<void*>(field, 0x28)) {
            if (!Handle(field).get()) throw std::runtime_error("Expired function schema");
            pushObject(state, field); lua_rawseti(state, -2, ++count);
        }
    }
    return 1;
}
#endif
}
void bind(lua_State* state) {
    luaL_newmetatable(state, "pal.engine.view");
    lua_pushcfunction(state, safe<index>); lua_setfield(state, -2, "__index");
    lua_pushcfunction(state, safe<assign>); lua_setfield(state, -2, "__newindex");
    lua_pushliteral(state, "engine view"); lua_setfield(state, -2, "__metatable"); lua_pop(state, 1);
    lua_newtable(state);
    const luaL_Reg api[] = {{"find", safe<findObject>}, {"objects", safe<findObjects>},
        {"construct", safe<constructObject>}, {"is_a", safe<isA>}, {"valid", valid}, {"clock", clock},
        {"schema", safe<schema>}, {"subscribe", safe<subscribe>}, {"discoveries", safe<discoveries>}, {"clicks", clicks}, {"messages", messages}, {"quit", safe<quit>}, {nullptr, nullptr}};
    luaL_setfuncs(state, api, 0); lua_setglobal(state, "Engine");
#ifdef PALMODS_DEVELOPMENT
    lua_getglobal(state, "Engine");
    lua_pushcfunction(state, safe<functions>); lua_setfield(state, -2, "functions"); lua_pop(state, 1);
#endif
}
}
