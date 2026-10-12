#pragma once
#include <cstddef>
#include <cstdint>
#include <string>
#include <unordered_map>
#include <mach-o/nlist.h>

namespace pal::engine {
struct Symbol { uintptr_t address; size_t size; };
class Symbols {
public:
    bool load();
    Symbol find(const std::string& name) const;
    template<class T> T get(const char* name) const {
        return reinterpret_cast<T>(find(name).address);
    }
    const std::string& uuid() const { return uuid_; }
private:
    mutable std::unordered_map<std::string, Symbol> entries_;
    const nlist_64* records_ = nullptr;
    const char* names_ = nullptr;
    uint32_t count_ = 0;
    uint32_t stringSize_ = 0;
    intptr_t slide_ = 0;
    std::string uuid_;
};
Symbols& symbols();
}
