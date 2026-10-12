#include "engine.hpp"
#include <CoreFoundation/CoreFoundation.h>
#include <stdexcept>
#include <cstdio>

namespace pal::engine {
namespace {
void* item(int32_t index) {
    static auto* registry = symbols().get<void*>("_GUObjectArray");
    if (!registry || index < 0 || index >= read<int32_t>(registry, 0x24)) return nullptr;
    auto** chunks = read<void**>(registry, 0x10);
    if (!chunks || !chunks[index >> 16]) return nullptr;
    return static_cast<char*>(chunks[index >> 16]) + (index & 65535) * 24;
}
template<class T> T required(const char* key) {
    auto fn = symbols().get<T>(key);
    if (!fn) throw std::runtime_error("Required engine symbol is unavailable");
    return fn;
}
size_t virtualSlot(const char* method) {
    auto table = symbols().find("__ZTV9FProperty");
    auto address = symbols().find(method).address;
    if (!table.address || !address || table.size > 16384) throw std::runtime_error("Invalid property ABI");
    auto* slots = reinterpret_cast<uintptr_t*>(table.address + 16);
    for (size_t i = 0; i < (table.size - 16) / 8; ++i) if (slots[i] == address) return i;
    throw std::runtime_error("Property operation is unavailable");
}
}
Handle::Handle(void* object) {
    if (!object) return;
    auto id = read<int32_t>(object, 12);
    auto* slot = item(id);
    if (slot && read<void*>(slot, 0) == object) {
        pointer = object; index = id; serial = read<int32_t>(slot, 16);
        if (!serial) {
            static auto next = required<int32_t (*)(void*, int32_t)>("__ZN13FUObjectArray20AllocateSerialNumberEi");
            serial = next(symbols().get<void*>("_GUObjectArray"), index);
        }
    }
}
void* Handle::get() const {
    auto* slot = item(index);
    if (!slot || read<void*>(slot, 0) != pointer || read<int32_t>(slot, 16) != serial) return nullptr;
    if ((read<uint32_t>(pointer, 8) & 0x00018000) || (read<uint32_t>(slot, 8) & 0x30000000)) return nullptr;
    return pointer;
}
std::u16string wide(const std::string& value) {
    auto string = CFStringCreateWithBytes(nullptr, reinterpret_cast<const UInt8*>(value.data()), value.size(), kCFStringEncodingUTF8, false);
    if (!string) throw std::runtime_error("Invalid UTF-8 string");
    std::u16string result(CFStringGetLength(string), 0);
    CFStringGetCharacters(string, CFRangeMake(0, result.size()), reinterpret_cast<UniChar*>(result.data()));
    CFRelease(string); return result;
}
std::string utf8(const char16_t* value, size_t count) {
    if (!value || count > 1048576) return {};
    auto string = CFStringCreateWithCharacters(nullptr, reinterpret_cast<const UniChar*>(value), count);
    auto capacity = CFStringGetMaximumSizeForEncoding(count, kCFStringEncodingUTF8) + 1;
    std::string result(capacity, 0);
    auto success = CFStringGetCString(string, result.data(), capacity, kCFStringEncodingUTF8);
    CFRelease(string);
    if (!success) throw std::runtime_error("Invalid UTF-16 string");
    result.resize(std::strlen(result.c_str())); return result;
}
Name name(const std::string& value) {
    static auto fn = required<void (*)(Name*, const char16_t*, int)>("__ZN5FNameC1EPKDs9EFindName");
    Name result; auto chars = wide(value); fn(&result, chars.c_str(), 1); return result;
}
std::string text(Name value) {
    static auto fn = required<int (*)(const Name*, char16_t*, uint32_t)>("__ZNK5FName8ToStringEPDsj");
    char16_t buffer[2048]{}; fn(&value, buffer, 2048);
    return utf8(buffer, std::char_traits<char16_t>::length(buffer));
}
std::string objectName(void* object) { return object ? text(read<Name>(object, 24)) : "None"; }
std::string objectPath(void* object) {
    std::string result;
    for (unsigned i = 0; object && i < 32; ++i) {
        result = objectName(object) + (result.empty() ? "" : "." + result);
        object = read<void*>(object, 32);
    }
    return result;
}
void* find(const std::string& path) {
    static auto fn = required<void* (*)(void*, void*, const char16_t*, bool)>("__Z16StaticFindObjectP6UClassP7UObjectPKDsb");
    auto chars = wide(path); return fn(nullptr, nullptr, chars.c_str(), false);
}
void* findFunction(void* object, const std::string& method) {
    static auto fn = required<void* (*)(void*, Name)>("__ZNK7UObject12FindFunctionE5FName");
    return fn(object, name(method));
}
void* findProperty(void* structure, const std::string& property) {
    static auto fn = required<void* (*)(void*, Name)>("__ZNK7UStruct18FindPropertyByNameE5FName");
    return fn(structure, name(property));
}
std::vector<void*> properties(void* structure) {
    std::vector<void*> result;
    for (auto* field = read<void*>(structure, 0x50); field && result.size() < 256; field = read<void*>(field, 0x20)) result.push_back(field);
    return result;
}
std::string propertyKind(void* property) { return text(read<Name>(read<void*>(property, 8), 0)); }
std::vector<Handle> objects(const std::string& className, size_t limit) {
    static auto* registry = symbols().get<void*>("_GUObjectArray");
    std::vector<Handle> result;
    auto count = read<int32_t>(registry, 0x24);
    auto classId = name(className).value;
    for (int32_t i = 0; i < count && result.size() < limit; ++i) {
        auto* slot = item(i); auto* object = slot ? read<void*>(slot, 0) : nullptr;
        if (!object || (read<uint32_t>(object, 8) & 0x10)) continue;
        if (read<uint32_t>(slot, 8) & 0x30000000) continue;
        for (auto* type = read<void*>(object, 16); type; type = read<void*>(type, 0x40)) {
            if (read<Name>(type, 24).value == classId) { Handle handle(object); if (handle.get()) result.push_back(handle); break; }
        }
    }
    return result;
}
void event(void* object, void* function, void* parameters) {
    static auto fn = required<void (*)(void*, void*, void*)>("__ZN7UObject12ProcessEventEP9UFunctionPv");
    if (!Handle(object).get() || !Handle(function).get()) throw std::runtime_error("Expired engine object");
    fn(object, function, parameters);
}
void* construct(void* type, void* outer) {
    static auto init = required<void (*)(void*, void*)>("__ZN32FStaticConstructObjectParametersC1EPK6UClass");
    static auto make = required<void* (*)(const void*)>("__Z30StaticConstructObject_InternalRK32FStaticConstructObjectParameters");
    static auto end = required<void (*)(void*)>("__ZN32FStaticConstructObjectParametersD1Ev");
    alignas(16) unsigned char params[144]{};
    init(params, type); write(params, 8, outer); auto* result = make(params); end(params); return result;
}
void initialize(void* property, void* value) {
    static auto slot = virtualSlot("__ZNK9FProperty23InitializeValueInternalEPv");
    read<void (**)(void*, void*)>(property, 0)[slot](property, value);
}
void destroy(void* property, void* value) {
    static auto slot = virtualSlot("__ZNK9FProperty20DestroyValueInternalEPv");
    read<void (**)(void*, void*)>(property, 0)[slot](property, value);
}
void* allocate(size_t bytes) {
    static auto fn = required<void* (*)(size_t, uint32_t)>("__ZN7FMemory6MallocEmj"); return fn(bytes, 16);
}
void release(void* memory) {
    static auto fn = required<void (*)(void*)>("__ZN7FMemory4FreeEPv"); if (memory) fn(memory);
}
}
