#include "transport.hpp"
#include <mutex>
#include <thread>
#include <unistd.h>

namespace pal::transport {
namespace {
struct Inbox { std::mutex mutex; std::vector<std::string> lines; size_t bytes = 0; };
Inbox& inbox() { static auto* value = new Inbox; return *value; }
void receive() {
    constexpr size_t maximum = 2 * 1024 * 1024;
    char buffer[16384]; std::string pending; bool discard = false;
    while (true) {
        auto count = read(STDIN_FILENO, buffer, sizeof(buffer));
        if (count <= 0) return;
        for (ssize_t i = 0; i < count; ++i) {
            if (buffer[i] == '\n') {
                if (!discard && !pending.empty()) {
                    auto& queue = inbox(); std::lock_guard lock(queue.mutex);
                    if (queue.lines.size() < 32 && queue.bytes + pending.size() <= maximum * 2) {
                        queue.bytes += pending.size(); queue.lines.push_back(std::move(pending));
                    }
                }
                pending.clear(); discard = false;
            } else if (!discard) {
                pending += buffer[i];
                if (pending.size() > maximum) { pending.clear(); discard = true; }
            }
        }
    }
}
}
void start() { std::thread(receive).detach(); }
std::vector<std::string> take() {
    auto& queue = inbox(); std::lock_guard lock(queue.mutex);
    std::vector<std::string> result; result.swap(queue.lines); queue.bytes = 0; return result;
}
}
