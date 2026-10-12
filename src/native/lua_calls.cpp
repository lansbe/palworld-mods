#include "lua_bridge.hpp"
#include <stdexcept>

namespace pal::script {
using namespace engine;
namespace {
struct Parameters {
    std::vector<unsigned char> bytes;
    std::vector<void*> fields;
    explicit Parameters(void* function) {
        auto size = read<uint16_t>(function, 0xb6);
        bytes.resize(size ? size : 1);
        try { for (auto* field : properties(function)) {
            auto flags = read<uint64_t>(field, 0x40);
            if (!(flags & 0x80)) continue;
            auto offset = read<int32_t>(field, 0x4c), length = read<int32_t>(field, 0x38);
            if (offset < 0 || length < 0 || offset + length > size) throw std::runtime_error("Invalid parameter layout");
            initialize(field, bytes.data() + offset); fields.push_back(field);
        } } catch (...) { for (auto* field : fields) destroy(field, data(field)); throw; }
    }
    ~Parameters() {
        for (auto* field : fields) destroy(field, data(field));
    }
    void* data(void* field) { return bytes.data() + read<int32_t>(field, 0x4c); }
};
int call(lua_State* state) {
    auto* target = object(state, 1);
    auto* function = object(state, lua_upvalueindex(1));
    if (!target || !function) throw std::runtime_error("Missing method target");
    Parameters parameters(function);
    int argument = 2; void* result = nullptr;
    for (auto* field : parameters.fields) {
        auto flags = read<uint64_t>(field, 0x40);
        if (flags & 0x400) { result = field; continue; }
        if (argument <= lua_gettop(state) && !lua_isnil(state, argument)) {
            setValue(state, argument, field, parameters.data(field));
        } else if (!(flags & 0x100) && propertyKind(field) != "ObjectProperty" && propertyKind(field) != "ClassProperty") {
            throw std::runtime_error("Missing parameter: " + text(read<Name>(field, 0x28)));
        }
        ++argument;
    }
    if (lua_gettop(state) >= argument) throw std::runtime_error("Too many method arguments");
    event(target, function, parameters.bytes.data());
    int returns = 0;
    if (result) { pushValue(state, result, parameters.data(result)); ++returns; }
    for (auto* field : parameters.fields) {
        auto flags = read<uint64_t>(field, 0x40);
        if ((flags & 0x100) && !(flags & 0x400)) { pushValue(state, field, parameters.data(field)); ++returns; }
    }
    return returns;
}
}
int invoke(lua_State* state) {
    try { return call(state); }
    catch (const std::exception& error) { lua_pushstring(state, error.what()); }
    return lua_error(state);
}
}
