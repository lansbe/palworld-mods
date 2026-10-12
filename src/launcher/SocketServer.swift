import Foundation
import Darwin

final class SocketServer {
    private let path: String
    private var descriptor: Int32 = -1
    private let capacity = DispatchSemaphore(value: 8)
    private let handler: ([String: Any], @escaping ([String: Any]) -> Void) -> Void

    init(path: String, handler: @escaping ([String: Any], @escaping ([String: Any]) -> Void) -> Void) {
        self.path = path; self.handler = handler
    }

    func start() throws {
        guard path.utf8.count < 104 else { throw HostError.message("The local socket path is too long.") }
        descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw HostError.message("Cannot create the local control socket.") }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: Array(path.utf8) + [0])
        }
        // The launcher owns the directory and holds the exclusive launch lock.
        unlink(path)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, chmod(path, 0o600) == 0, listen(descriptor, 8) == 0 else {
            close(descriptor); descriptor = -1
            throw HostError.message("Cannot open the local control socket.")
        }
        DispatchQueue.global().async { [weak self] in self?.acceptLoop() }
    }

    private func acceptLoop() {
        while descriptor >= 0 {
            let client = accept(descriptor, nil, nil)
            if client < 0 { break }
            guard capacity.wait(timeout: .now()) == .success else { close(client); continue }
            DispatchQueue.global().async { [weak self] in
                defer { close(client); self?.capacity.signal() }
                self?.serve(client)
            }
        }
    }

    private func serve(_ client: Int32) {
        var uid: uid_t = 0, gid: gid_t = 0
        guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else { return }
        var timeout = timeval(tv_sec: 20, tv_usec: 0), noPipe: Int32 = 1
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noPipe, socklen_t(MemoryLayout<Int32>.size))
        var data = Data(), bytes = [UInt8](repeating: 0, count: 4096)
        while data.count <= 65536 {
            let count = recv(client, &bytes, bytes.count, 0)
            guard count > 0 else { return }
            data.append(contentsOf: bytes.prefix(count))
            if data.contains(10) { break }
        }
        guard data.count <= 65536, let newline = data.firstIndex(of: 10),
            let request = try? JSONSerialization.jsonObject(with: data[..<newline]) as? [String: Any] else { return }
        let ready = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var response: [String: Any] = ["ok": false, "result": "The request timed out."]
        handler(request) { value in lock.lock(); response = value; lock.unlock(); ready.signal() }
        _ = ready.wait(timeout: .now() + 16)
        lock.lock(); let value = response; lock.unlock()
        guard var reply = try? jsonData(value) else { return }
        reply.append(10)
        reply.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                let count = send(client, base.advanced(by: offset), buffer.count-offset, 0)
                if count <= 0 { break }; offset += count
            }
        }
    }

    func stop() {
        if descriptor >= 0 { shutdown(descriptor, SHUT_RDWR); close(descriptor); descriptor = -1 }
        unlink(path)
    }
}
