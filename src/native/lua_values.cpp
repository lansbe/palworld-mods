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
        } else if (properties(schema).empty()) pushOpaqueStructure(state, schema, data, read<int32_t>(property, 0x38));
        else pushStructure(state, schema, data);
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
        auto setMask = read<uint8_t>(property, 0x7a);
        auto value = read<uint8_t>(data, offset);
        write<uint8_t>(data, offset, (value & ~mask) | (lua_toboolean(state, index) ? setMask : 0));
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
            // The engine copies ownership correctly, including non-reflected native fields.
            copyStructure(schema, data, source->data());
        } else if (!copyOpaqueStructure(state, index, schema, data)) {
            if (!lua_istable(state, index)) throw std::runtime_error("A structure table is required");
            for (auto* field : properties(schema)) {
                auto key = text(read<Name>(field, 0x28)); lua_getfield(state, index, key.c_str());
                if (!lua_isnil(state, -1)) setValue(state, -1, field, static_cast<char*>(data) + read<int32_t>(field, 0x4c));
                lua_pop(state, 1);
            }
        }
    } else if (kind == "ArrayProperty" && lua_istable(state, index)) {
        auto count = lua_rawlen(state, index);
        auto* inner = read<void*>(property, 0x78);
        auto size = read<int32_t>(inner, 0x38);
        if (count > 4096 || size < 1 || size > 65536 || count * size > 16777216)
            throw std::runtime_error("Array exceeds the assignment limit");
        lua_pushnil(state);
        while (lua_next(state, index)) {
            if (!lua_isinteger(state, -2) || lua_tointeger(state, -2) < 1 ||
                static_cast<size_t>(lua_tointeger(state, -2)) > count)
                throw std::runtime_error("A dense array is required");
            lua_pop(state, 1);
        }
        auto* buffer = count ? static_cast<char*>(allocate(count * size)) : nullptr;
        size_t initialized = 0;
        try {
            for (size_t i = 0; i < count; ++i) {
                initialize(inner, buffer + i * size); ++initialized;
                lua_rawgeti(state, index, i + 1);
                if (lua_isnil(state, -1)) throw std::runtime_error("A dense array is required");
                setValue(state, -1, inner, buffer + i * size); lua_pop(state, 1);
            }
        } catch (...) {
            for (size_t i = 0; i < initialized; ++i) destroy(inner, buffer + i * size);
            release(buffer); throw;
        }
        destroy(property, data); initialize(property, data);
        write(data, 0, String{reinterpret_cast<char16_t*>(buffer), static_cast<int32_t>(count), static_cast<int32_t>(count)});
    } else if (kind == "DelegateProperty" && lua_istable(state, index)) {
        if (read<int32_t>(property, 0x38) != 16) throw std::runtime_error("Unsupported delegate layout");
        lua_getfield(state, index, "object"); auto* target = object(state, -1); lua_pop(state, 1);
        lua_getfield(state, index, "function"); auto method = string(state, -1); lua_pop(state, 1);
        auto* function = target ? findFunction(target, method) : nullptr;
        auto* signature = read<void*>(property, 0x78);
        if (!function || !signature || read<uint16_t>(function, 0xb6) || read<uint16_t>(signature, 0xb6))
            throw std::runtime_error("Incompatible delegate function");
        Handle handle(target);
        write<int32_t>(data, 0, handle.index); write<int32_t>(data, 4, handle.serial);
        write(data, 8, name(method));
    } else throw std::runtime_error("Unsupported property assignment: " + kind);
}
}
