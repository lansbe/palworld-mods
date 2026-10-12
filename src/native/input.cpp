#include "lua_bridge.hpp"
#include <cmath>
#include <map>
#include <stdexcept>

namespace pal::script {
using namespace engine;
namespace {
void* controller(lua_State* state) {
    auto* value = object(state, 1);
    for (auto* type = value ? read<void*>(value, 16) : nullptr; type; type = read<void*>(type, 0x40)) {
        if (objectName(type) == "PalPlayerController") return value;
    }
    throw std::runtime_error("A live player controller is required");
}
template<class T> T required(const std::string& symbol) {
    auto fn = symbols().get<T>(symbol.c_str());
    if (!fn) throw std::runtime_error("This input is unavailable in this game build");
    return fn;
}
double number(lua_State* state, int index) {
    int valid = 0; auto value = lua_tonumberx(state, index, &valid);
    if (!valid || !std::isfinite(value)) throw std::runtime_error("A finite input value is required");
    return value;
}
int input(lua_State* state) {
    auto* target = controller(state);
    static const std::map<std::string, std::string> actions = {
        {"fire", "WeaponUseButton"}, {"aim", "WeaponAimButton"}, {"alt_fire", "WeaponAltFireButton"},
        {"sprint", "DashButton"}, {"dodge", "RollingButton"}, {"jump", "JumpButton"},
        {"crouch", "CrouchButton"}, {"reload", "ReloadButtonKeyboard"}, {"throw_pal", "ThrowPalButton"},
        {"throw_object", "ThrowObjectButton"}, {"interact2", "Interact2Button"},
        {"interact3", "Interact3Button"}, {"interact4", "Interact4Button"}};
    auto found = actions.find(string(state, 2));
    if (found == actions.end() || !lua_isboolean(state, 3)) throw std::runtime_error("Invalid player input");
    auto method = std::string(lua_toboolean(state, 3) ? "OnPressed" : "OnReleased") + found->second;
    required<void (*)(void*)>("__ZN20APalPlayerController" + std::to_string(method.size()) + method + "Ev")(target);
    return 0;
}
int axes(lua_State* state) {
    auto* target = controller(state);
    auto forward = number(state, 2), right = number(state, 3);
    if (std::abs(forward) > 1.00001 || std::abs(right) > 1.00001) throw std::runtime_error("Movement input is out of range");
    static auto first = required<void (*)(void*, float)>("__ZN20APalPlayerController11MoveForwardEf");
    static auto second = required<void (*)(void*, float)>("__ZN20APalPlayerController9MoveRightEf");
    first(target, forward); second(target, right); return 0;
}
struct Guid { uint32_t a, b, c, d; };
struct Slot { Guid container; int32_t index, count; };
struct Instance { Guid player, instance; void* debug = nullptr; int32_t count = 0, capacity = 0; };
static_assert(sizeof(Slot) == 24 && sizeof(Instance) == 48);
Guid guid(lua_State* state, int index, const char* key) {
    lua_getfield(state, index, key);
    if (!lua_istable(state, -1)) throw std::runtime_error("A GUID table is required");
    uint32_t values[4]; int i = 0;
    for (const auto* field : {"A", "B", "C", "D"}) {
        lua_getfield(state, -1, field); auto value = number(state, -1); lua_pop(state, 1);
        if (std::trunc(value) != value || value < INT32_MIN || value > UINT32_MAX) throw std::runtime_error("Invalid GUID component");
        values[i++] = static_cast<uint32_t>(static_cast<int64_t>(value));
    }
    lua_pop(state, 1); return {values[0], values[1], values[2], values[3]};
}
int useItem(lua_State* state) {
    auto* target = controller(state);
    auto container = guid(state, 2, "container");
    lua_getfield(state, 2, "index"); auto index = number(state, -1); lua_pop(state, 1);
    if (std::trunc(index) != index || index < 0 || index >= 4096) throw std::runtime_error("Invalid inventory slot");
    Instance instance{guid(state, 3, "PlayerUId"), guid(state, 3, "InstanceId")};
    static auto owns = required<bool (*)(void*, const Instance&)>("__ZN20APalPlayerController17IsOwningPalOrSelfERK14FPalInstanceID");
    static auto use = required<void (*)(void*, const Slot&, const Instance&)>("__ZN20APalPlayerController25RequestUseItemToCharacterERK20FPalItemSlotIdAndNumRK14FPalInstanceID");
    if (!owns(target, instance)) throw std::runtime_error("The item target is not owned by this player");
    use(target, Slot{container, static_cast<int32_t>(index), 1}, instance);
    lua_pushboolean(state, true); return 1;
}
template<int (*Operation)(lua_State*)> int safe(lua_State* state) {
    try { return Operation(state); }
    catch (const std::exception& error) { lua_pushstring(state, error.what()); }
    return lua_error(state);
}
}
void bindInput(lua_State* state) {
    lua_getglobal(state, "Engine");
    const luaL_Reg api[] = {{"input", safe<input>}, {"axes", safe<axes>}, {"use_item", safe<useItem>}, {nullptr, nullptr}};
    luaL_setfuncs(state, api, 0); lua_pop(state, 1);
}
}
