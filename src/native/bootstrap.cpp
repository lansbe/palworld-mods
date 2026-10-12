#include "symbols.hpp"
#include "engine.hpp"
#include "lua_bridge.hpp"
#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <thread>
#include <vector>

namespace {
using Tick = void (*)(void*, float, bool);
Tick originalTick = nullptr;
std::atomic<bool> stopping{false};
std::vector<uintptr_t>* replacement = nullptr;
void tick(void* engine, float delta, bool idle) {
    originalTick(engine, delta, idle);
    auto* exiting = pal::engine::symbols().get<const bool*>("_GIsRequestingExit");
    if (exiting && *exiting) { stopping = true; return; }
    static unsigned frames = 0;
    if (++frames == 1) { std::fprintf(stderr, "[PalMods] Native game-thread tick active\n"); }
    pal::script::tick(delta);
}
bool attach() {
    auto& symbols = pal::engine::symbols();
    auto** global = symbols.get<void**>("_GEngine");
    if (!global || !*global) return false;
    auto table = symbols.find("__ZTV14UPalGameEngine");
    auto target = symbols.find("__ZN11UGameEngine4TickEfb");
    if (!table.address || table.size < 24 || table.size > 32768 || !target.address) return false;
    auto* engine = *global;
    auto** slot = reinterpret_cast<uintptr_t**>(engine);
    auto* current = __atomic_load_n(slot, __ATOMIC_ACQUIRE);
    if (reinterpret_cast<uintptr_t>(current) != table.address + 16) return false;
    auto count = (table.size - 16) / sizeof(uintptr_t);
    size_t index = count;
    for (size_t i = 0; i < count; ++i) if (current[i] == target.address) { index = i; break; }
    if (index == count) return false;
    // Preserve the Itanium RTTI header and the complete original table.
    replacement = new std::vector<uintptr_t>(table.size / sizeof(uintptr_t));
    std::memcpy(replacement->data(), reinterpret_cast<void*>(table.address), table.size);
    originalTick = reinterpret_cast<Tick>(target.address);
    (*replacement)[index + 2] = reinterpret_cast<uintptr_t>(&tick);
    __atomic_store_n(slot, replacement->data() + 2, __ATOMIC_RELEASE);
    std::fprintf(stderr, "[PalMods] Attached native runtime; profile=%s slot=%zu\n", symbols.uuid().c_str(), index);
    return true;
}
void initialize() {
    if (!pal::engine::symbols().load()) {
        std::fprintf(stderr, "[PalMods] Unsupported executable; runtime disabled; observed=%s\n", pal::engine::symbols().uuid().c_str()); return;
    }
    for (unsigned i = 0; i < 600 && !stopping; ++i) {
        if (attach()) return;
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    std::fprintf(stderr, "[PalMods] Engine not available; runtime disabled\n");
}
__attribute__((constructor)) void start() {
    std::thread(initialize).detach();
}
}
