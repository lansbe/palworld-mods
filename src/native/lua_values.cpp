#include "lua_bridge.hpp"
#include <cmath>
#include <stdexcept>

namespace pal::script {
using namespace engine;
namespace {
void pushString(lua_State* state, const std::string& value) { lua_pushlstring(state, value.data(), value.size()); }
void pushStructure(lua_State* state, void* structure, void* data) {
    lua_newtable(state);
    for (auto* field : properties(structure)) {
        auto key = text(read<Name>(field, 0x28));
        pushValue(state, field, static_cast<char*>(data) + read<int32_t>(field, 0x4c));
        lua_setfield(state, -2, key.c_str());
    }
}
void makeText(void* destination, const std::string& value) {
    struct Parameters { String source; alignas(8) unsigned char result[24]{}; };
    static Handle library(find("/Script/Engine.Default__KismetTextLibrary"));
    static Handle function(find("/Script/Engine.KismetTextLibrary:Conv_StringToText"));
    auto chars = wide(value); chars.push_back(0);
    Parameters parameters{{chars.data(), static_cast<int32_t>(chars.size()), static_cast<int32_t>(chars.size())}};
    event(library.get(), function.get(), &parameters);
    std::memcpy(destination, parameters.result, 24);
}
double number(lua_State* state, int index) {
    int valid = 0; double value = lua_tonumberx(state, index, &valid);
    if (!valid || !std::isfinite(value)) throw std::runtime_error("A finite number is required");
    return value;
}
}
void pushValue(lua_State* state, void* property, void* data, const View* parent) {
    auto kind = propertyKind(property);
    if (kind == "ObjectProperty" || kind == "ClassProperty") pushObject(state, read<void*>(data, 0));
    else if (kind == "BoolProperty") {
        auto offset = read<uint8_t>(property, 0x79), mask = read<uint8_t>(property, 0x7b);
        lua_pushboolean(state, (read<uint8_t>(data, offset) & mask) != 0);
    } else if (kind == "FloatProperty") lua_pushnumber(state, read<float>(data, 0));
    else if (kind == "DoubleProperty") lua_pushnumber(state, read<double>(data, 0));
    else if (kind == "IntProperty") lua_pushinteger(state, read<int32_t>(data, 0));
    else if (kind == "Int64Property") lua_pushinteger(state, read<int64_t>(data, 0));
    else if (kind == "UInt32Property") lua_pushinteger(state, read<uint32_t>(data, 0));
    else if (kind == "ByteProperty") lua_pushinteger(state, read<uint8_t>(data, 0));
    else if (kind == "EnumProperty") pushValue(state, read<void*>(property, 0x78), data);
    else if (kind == "NameProperty") pushString(state, text(read<Name>(data, 0)));
    else if (kind == "StrProperty") {
        auto value = read<String>(data, 0);
        pushString(state, utf8(value.data, value.count > 0 ? value.count - 1 : 0));
    } else if (kind == "TextProperty") {
        static auto fn = symbols().get<const String& (*)(void*)>("__ZNK5FText8ToStringEv");
        auto value = fn(data); pushString(state, utf8(value.data, value.count > 0 ? value.count - 1 : 0));
    } else if (kind == "StructProperty") {
        auto* schema = read<void*>(property, 0x78);
        if (parent) {
            auto* reference = static_cast<View*>(lua_newuserdatauv(state, sizeof(View), 0));
            new (reference) View{parent->owner, schema,
                static_cast<size_t>(static_cast<char*>(data) - static_cast<char*>(parent->owner.get())), false};
            luaL_setmetatable(state, "pal.engine.view");
        } else pushStructure(state, schema, data);
    } else if (kind == "ArrayProperty") {
        auto array = read<String>(data, 0);
        auto* inner = read<void*>(property, 0x78);
        auto size = read<int32_t>(inner, 0x38);
        if (array.count < 0 || array.count > 65536 || size < 1 || size > 65536) throw std::runtime_error("Invalid engine array");
        lua_createtable(state, array.count, 0);
        for (int i = 0; i < array.count; ++i) {
            pushValue(state, inner, reinterpret_cast<char*>(array.data) + i * size);
            lua_rawseti(state, -2, i + 1);
        }
    } else throw std::runtime_error("Unsupported property type: " + kind);
}
void setValue(lua_State* state, int index, void* property, void* data) {
    index = lua_absindex(state, index);
    auto kind = propertyKind(property);
    if (kind == "ObjectProperty" || kind == "ClassProperty") write(data, 0, object(state, index));
    else if (kind == "BoolProperty") {
        if (!lua_isboolean(state, index)) throw std::runtime_error("A boolean is required");
        auto offset = read<uint8_t>(property, 0x79), mask = read<uint8_t>(property, 0x7b);
        auto value = read<uint8_t>(data, offset);
        write<uint8_t>(data, offset, lua_toboolean(state, index) ? value | mask : value & ~mask);
    } else if (kind == "FloatProperty") write<float>(data, 0, number(state, index));
    else if (kind == "DoubleProperty") write(data, 0, number(state, index));
    else if (kind == "IntProperty" || kind == "UInt32Property" || kind == "Int64Property" || kind == "ByteProperty") {
        auto value = number(state, index);
        if (std::trunc(value) != value) throw std::runtime_error("An integer is required");
        if (kind == "ByteProperty" && value >= 0 && value <= 255) write<uint8_t>(data, 0, value);
        else if (kind == "IntProperty" && value >= INT32_MIN && value <= INT32_MAX) write<int32_t>(data, 0, value);
        else if (kind == "UInt32Property" && value >= 0 && value <= UINT32_MAX) write<uint32_t>(data, 0, value);
        else if (kind == "Int64Property" && value >= INT64_MIN && value < static_cast<double>(INT64_MAX)) write<int64_t>(data, 0, value);
        else throw std::runtime_error("Integer is outside the property range");
    } else if (kind == "EnumProperty") setValue(state, index, read<void*>(property, 0x78), data);
    else if (kind == "NameProperty") write(data, 0, name(string(state, index)));
    else if (kind == "StrProperty") {
        auto chars = wide(string(state, index)); chars.push_back(0);
        auto* buffer = static_cast<char16_t*>(allocate(chars.size() * 2));
        std::memcpy(buffer, chars.data(), chars.size() * 2);
        auto previous = read<String>(data, 0); release(previous.data);
        write(data, 0, String{buffer, static_cast<int32_t>(chars.size()), static_cast<int32_t>(chars.size())});
    } else if (kind == "TextProperty") {
        destroy(property, data); initialize(property, data); makeText(data, string(state, index));
    } else if (kind == "StructProperty") {
        auto* schema = read<void*>(property, 0x78);
        if (auto* source = view(state, index)) {
            if (source->schema != schema) throw std::runtime_error("Structure types differ");
            auto count = read<int32_t>(property, 0x38);
            // Plain table conversion prevents borrowing an engine-owned value.
            pushStructure(state, schema, source->data()); setValue(state, -1, property, data); lua_pop(state, 1);
            (void)count;
        } else {
            if (!lua_istable(state, index)) throw std::runtime_error("A structure table is required");
            for (auto* field : properties(schema)) {
                auto key = text(read<Name>(field, 0x28)); lua_getfield(state, index, key.c_str());
                if (!lua_isnil(state, -1)) setValue(state, -1, field, static_cast<char*>(data) + read<int32_t>(field, 0x4c));
                lua_pop(state, 1);
            }
        }
    } else if (kind == "ArrayProperty" && lua_istable(state, index) && lua_rawlen(state, index) == 0) {
        // Empty out-parameter arrays are initialized by the engine.
    } else throw std::runtime_error("Unsupported property assignment: " + kind);
}
}
