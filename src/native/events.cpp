#include "events.hpp"
#include <cstdio>

namespace pal::events {
namespace {
using NativeCall = void (*)(void*, void*, void*);
NativeCall original = nullptr;
std::vector<engine::Handle>& clicks() { static auto* value = new std::vector<engine::Handle>; return *value; }
void clicked(void* object, void* frame, void* result) {
    engine::Handle handle(object);
    original(object, frame, result);
    if (handle.get() && clicks().size() < 128) clicks().push_back(handle);
}
}
void attach() {
    if (original) return;
    auto* function = engine::find("/Script/CommonUI.CommonButtonBase:HandleButtonClicked");
    if (!function) return;
    if (!(engine::read<uint32_t>(function, 0xb0) & 0x400) || engine::read<uint16_t>(function, 0xb6) != 0) {
        std::fprintf(stderr, "[PalMods] Button ABI mismatch; menu events disabled\n"); return;
    }
    original = engine::read<NativeCall>(function, 0xd8);
    engine::write<NativeCall>(function, 0xd8, &clicked);
    std::fprintf(stderr, "[PalMods] Native menu events ready\n");
}
std::vector<engine::Handle> takeClicks() {
    std::vector<engine::Handle> result; result.swap(clicks()); return result;
}
}
