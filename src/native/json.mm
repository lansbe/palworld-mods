#import <Foundation/Foundation.h>
#include "lua_bridge.hpp"
#include <stdexcept>

namespace pal::script {
namespace {
id decodeValue(lua_State* state, int index, unsigned depth) {
    if (depth > 32) throw std::runtime_error("JSON nesting exceeds 32 levels");
    index = lua_absindex(state, index);
    switch (lua_type(state, index)) {
    case LUA_TNIL: return NSNull.null;
    case LUA_TBOOLEAN: return @(lua_toboolean(state, index) != 0);
    case LUA_TNUMBER:
        if (lua_isinteger(state, index)) return @(lua_tointeger(state, index));
        return @(lua_tonumber(state, index));
    case LUA_TSTRING: {
        size_t length; const char* bytes = lua_tolstring(state, index, &length);
        NSString* value = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
        if (!value) throw std::runtime_error("JSON strings must be valid UTF-8");
        return value;
    }
    case LUA_TTABLE: {
        size_t count = lua_rawlen(state, index), keys = 0;
        bool array = count > 0;
        if (lua_getmetatable(state, index)) {
            lua_getfield(state, -1, "__json_array");
            array = array || lua_toboolean(state, -1);
            lua_pop(state, 2);
        }
        lua_pushnil(state);
        while (lua_next(state, index)) {
            if (++keys > 65536) throw std::runtime_error("JSON container exceeds 65536 values");
            array = array && lua_isinteger(state, -2) && lua_tointeger(state, -2) >= 1 && lua_tointeger(state, -2) <= static_cast<lua_Integer>(count);
            lua_pop(state, 1);
        }
        if (array && keys == count) {
            NSMutableArray* values = [NSMutableArray arrayWithCapacity:count];
            for (size_t i = 1; i <= count; ++i) {
                lua_rawgeti(state, index, i); [values addObject:decodeValue(state, -1, depth + 1)]; lua_pop(state, 1);
            }
            return values;
        }
        NSMutableDictionary* values = [NSMutableDictionary dictionaryWithCapacity:keys];
        lua_pushnil(state);
        while (lua_next(state, index)) {
            if (lua_type(state, -2) != LUA_TSTRING) throw std::runtime_error("JSON object keys must be strings");
            NSString* key = decodeValue(state, -2, depth + 1);
            values[key] = decodeValue(state, -1, depth + 1); lua_pop(state, 1);
        }
        return values;
    }
    default: throw std::runtime_error("Value cannot be encoded as JSON");
    }
}
void encodeValue(lua_State* state, id value, unsigned depth) {
    if (depth > 32) throw std::runtime_error("JSON nesting exceeds 32 levels");
    if ([value isKindOfClass:NSString.class]) {
        NSData* data = [value dataUsingEncoding:NSUTF8StringEncoding]; lua_pushlstring(state, static_cast<const char*>(data.bytes), data.length);
    } else if ([value isKindOfClass:NSNumber.class]) {
        if (CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) lua_pushboolean(state, [value boolValue]);
        else if (std::strchr("fd", [value objCType][0])) lua_pushnumber(state, [value doubleValue]);
        else lua_pushinteger(state, [value longLongValue]);
    } else if ([value isKindOfClass:NSArray.class]) {
        lua_createtable(state, static_cast<int>([value count]), 0); size_t index = 0;
        luaL_getmetatable(state, "PalMods.JsonArray"); lua_setmetatable(state, -2);
        for (id entry in value) { encodeValue(state, entry, depth + 1); lua_rawseti(state, -2, ++index); }
    } else if ([value isKindOfClass:NSDictionary.class]) {
        lua_createtable(state, 0, static_cast<int>([value count]));
        for (NSString* key in value) { encodeValue(state, value[key], depth + 1); lua_setfield(state, -2, key.UTF8String); }
    } else lua_pushnil(state);
}
int encode(lua_State* state) {
    @autoreleasepool {
        try {
            id value = decodeValue(state, 1, 0);
            NSError* error = nil;
            NSData* data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys | NSJSONWritingFragmentsAllowed error:&error];
            if (!data || data.length > 1048576) throw std::runtime_error("Invalid or oversized JSON value");
            lua_pushlstring(state, static_cast<const char*>(data.bytes), data.length); return 1;
        } catch (const std::exception& error) { lua_pushstring(state, error.what()); }
    }
    return lua_error(state);
}
int decode(lua_State* state) {
    @autoreleasepool {
        try {
            auto bytes = string(state, 1);
            NSData* data = [NSData dataWithBytes:bytes.data() length:bytes.size()];
            NSError* error = nil;
            id value = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:&error];
            if (!value) throw std::runtime_error("Invalid JSON document");
            encodeValue(state, value, 0); return 1;
        } catch (const std::exception& error) { lua_pushstring(state, error.what()); }
    }
    return lua_error(state);
}
int array(lua_State* state) {
    if (lua_isnoneornil(state, 1)) lua_newtable(state);
    else { luaL_checktype(state, 1, LUA_TTABLE); lua_pushvalue(state, 1); }
    luaL_getmetatable(state, "PalMods.JsonArray"); lua_setmetatable(state, -2);
    return 1;
}
}
void bindJson(lua_State* state) {
    luaL_newmetatable(state, "PalMods.JsonArray");
    lua_pushboolean(state, true); lua_setfield(state, -2, "__json_array"); lua_pop(state, 1);
    lua_getglobal(state, "Engine");
    lua_pushcfunction(state, array); lua_setfield(state, -2, "array");
    lua_pushcfunction(state, encode); lua_setfield(state, -2, "json_encode");
    lua_pushcfunction(state, decode); lua_setfield(state, -2, "json_decode"); lua_pop(state, 1);
}
}
