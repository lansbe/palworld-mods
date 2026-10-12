#include "symbols.hpp"
#include <cstring>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>

namespace pal::engine {
Symbols& symbols() { static auto* value = new Symbols; return *value; }
bool Symbols::load() {
    // The profile is tied to a shipped executable, never a user or saved world.
    constexpr auto expected = "486483b87f7b378781631d46c369c045";
    const mach_header_64* header = nullptr;
    intptr_t slide = 0;
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        auto* candidate = reinterpret_cast<const mach_header_64*>(_dyld_get_image_header(i));
        if (candidate && candidate->magic == MH_MAGIC_64 && candidate->filetype == MH_EXECUTE) {
            header = candidate; slide = _dyld_get_image_vmaddr_slide(i); break;
        }
    }
    if (!header) return false;
    const symtab_command* table = nullptr;
    const segment_command_64* link = nullptr;
    auto* command = reinterpret_cast<const load_command*>(header + 1);
    for (uint32_t i = 0; i < header->ncmds; ++i) {
        if (command->cmdsize < sizeof(load_command)) return false;
        if (command->cmd == LC_UUID) {
            auto* bytes = reinterpret_cast<const uuid_command*>(command)->uuid;
            constexpr char hex[] = "0123456789abcdef";
            for (size_t j = 0; j < 16; ++j) {
                uuid_ += hex[bytes[j] >> 4]; uuid_ += hex[bytes[j] & 15];
            }
        }
        if (command->cmd == LC_SYMTAB) table = reinterpret_cast<const symtab_command*>(command);
        if (command->cmd == LC_SEGMENT_64) {
            auto* segment = reinterpret_cast<const segment_command_64*>(command);
            if (!std::strcmp(segment->segname, SEG_LINKEDIT)) link = segment;
        }
        command = reinterpret_cast<const load_command*>(reinterpret_cast<const char*>(command) + command->cmdsize);
    }
    if (uuid_ != expected || !table || !link) return false;
    auto base = slide + link->vmaddr - link->fileoff;
    names_ = reinterpret_cast<const char*>(base + table->stroff);
    records_ = reinterpret_cast<const nlist_64*>(base + table->symoff);
    count_ = table->nsyms; stringSize_ = table->strsize; slide_ = slide;
    return true;
}
Symbol Symbols::find(const std::string& name) const {
    auto it = entries_.find(name);
    if (it != entries_.end()) return it->second;
    Symbol result{};
    uint64_t value = 0;
    for (uint32_t i = 0; i < count_; ++i) {
        const auto& record = records_[i];
        auto offset = record.n_un.n_strx;
        if (!record.n_value || (record.n_type & N_STAB) || offset >= stringSize_) continue;
        if (name.size() >= stringSize_ - offset) continue;
        if (std::memcmp(names_ + offset, name.c_str(), name.size() + 1) == 0) {
            value = record.n_value; result.address = slide_ + value; break;
        }
    }
    uint64_t next = UINT64_MAX;
    if (value) for (uint32_t i = 0; i < count_; ++i) {
        auto candidate = records_[i].n_value;
        if (!(records_[i].n_type & N_STAB) && candidate > value && candidate < next) next = candidate;
    }
    if (next != UINT64_MAX) result.size = next - value;
    entries_.emplace(name, result);
    return result;
}
}
