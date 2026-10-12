#include "discovery.hpp"
#include <chrono>
#include <unordered_map>

namespace pal::discovery {
namespace {
struct Subscription {
    engine::Name name;
    std::unordered_map<int32_t, engine::Handle> seen;
};
std::map<std::string, Subscription>& subscriptions() {
    static auto* value = new std::map<std::string, Subscription>; return *value;
}
}
void subscribe(const std::string& name) {
    if (subscriptions().contains(name)) return;
    Subscription entry{engine::name(name), {}};
    for (auto handle : engine::objects(name)) entry.seen.emplace(handle.index, handle);
    subscriptions().emplace(name, std::move(entry));
}
std::map<std::string, std::vector<engine::Handle>> poll() {
    using namespace engine;
    std::map<std::string, std::vector<Handle>> result;
    if (subscriptions().empty()) return result;
    static auto* registry = symbols().get<void*>("_GUObjectArray");
    static int32_t cursor = 0, previousCount = 0;
    auto count = read<int32_t>(registry, 0x24);
    auto** chunks = read<void**>(registry, 0x10);
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::microseconds(300);
    // Newly appended slots get priority. Reused slots are covered by the bounded sweep.
    int32_t added = previousCount; previousCount = count;
    for (unsigned visited = 0; visited < 4096; ++visited) {
        if ((visited & 63) == 0 && std::chrono::steady_clock::now() >= deadline) break;
        if (!count) break;
        int32_t index = added < count ? added++ : cursor++ % count;
        if (cursor >= count) cursor = 0;
        auto* slot = static_cast<char*>(chunks[index >> 16]) + (index & 65535) * 24;
        auto* object = read<void*>(slot, 0);
        if (!object || (read<uint32_t>(object, 8) & 0x00018610) || (read<uint32_t>(slot, 8) & 0x30000000)) continue;
        for (auto& [label, subscription] : subscriptions()) {
            auto found = subscription.seen.find(index);
            if (found != subscription.seen.end() && found->second.get() == object) continue;
            if (found != subscription.seen.end()) subscription.seen.erase(found);
            for (auto* type = read<void*>(object, 16); type; type = read<void*>(type, 0x40)) {
                if (read<Name>(type, 24).value != subscription.name.value) continue;
                Handle handle(object);
                if (handle.get()) { subscription.seen[index] = handle; result[label].push_back(handle); }
                break;
            }
        }
    }
    return result;
}
}
