#include "UpdateKeychain.h"
#include <Security/Security.h>

void PalModsKeychainInteraction(bool allowed) {
    // Unsandboxed ad hoc apps use the legacy login Keychain. LAContext does not
    // suppress its ACL dialogs; this process-local switch prevents startup hangs.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    SecKeychainSetUserInteractionAllowed(allowed);
#pragma clang diagnostic pop
}
