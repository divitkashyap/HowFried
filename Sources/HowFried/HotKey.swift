import AppKit
import Carbon

final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { owner.action?() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(key: String, control: Bool, option: Bool, command: Bool) -> Bool {
        if let reference { UnregisterEventHotKey(reference); self.reference = nil }
        let codes: [String: UInt32] = ["B": 11, "G": 5, "J": 38, "K": 40, "P": 35, "T": 17]
        guard let code = codes[key], control || option || command, handler != nil else { return false }
        let modifiers: UInt32 = (control ? UInt32(controlKey) : 0) | (option ? UInt32(optionKey) : 0) | (command ? UInt32(cmdKey) : 0)
        return RegisterEventHotKey(code, modifiers, EventHotKeyID(signature: 0x48465244, id: 1), GetApplicationEventTarget(), 0, &reference) == noErr
    }
    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}
