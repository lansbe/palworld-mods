#pragma once
#include "engine.hpp"
#include <map>
namespace pal::discovery {
void subscribe(const std::string& name);
std::map<std::string, std::vector<engine::Handle>> poll();
}
