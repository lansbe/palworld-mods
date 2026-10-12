#pragma once
#include "engine.hpp"
extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}

namespace pal::script {
struct View {
    engine::Handle owner;
    void* schema = nullptr;
    size_t offset = 0;
    bool object = true;
    void* data() const;
};
void pushObject(lua_State* state, void* object);
void pushValue(lua_State* state, void* property, void* data, const View* parent = nullptr);
void setValue(lua_State* state, int index, void* property, void* data);
View* view(lua_State* state, int index);
void* object(lua_State* state, int index);
std::string string(lua_State* state, int index);
void bind(lua_State* state);
void bindJson(lua_State* state);
void bindInput(lua_State* state);
void bindEnums(lua_State* state);
int invoke(lua_State* state);
void tick(float delta);
}
