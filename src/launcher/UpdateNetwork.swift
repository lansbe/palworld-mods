import Foundation

// One bounded request per instance. Credentials never follow redirects to asset hosts.
final class UpdateDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let limit: Int
    private var bytes = Data()
    private var continuation: CheckedContinuation<Data, Error>?
    private var session: URLSession?
    private let lock = NSLock()
    private var cancelled = false
    init(limit: Int) { self.limit = limit }

    func fetch(_ url: URL, token: String, binary: Bool = false) async throws -> Data {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { completion in
                lock.lock(); defer { lock.unlock() }
                if cancelled { completion.resume(throwing: CancellationError()); return }
                continuation = completion
                var request = URLRequest(url: url)
                request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
                request.setValue(binary ? "application/octet-stream" : "application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
                request.setValue("PalworldMods-Updater", forHTTPHeaderField: "User-Agent")
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 180
                config.urlCache = nil; config.httpCookieStorage = nil; config.urlCredentialStorage = nil
                let network = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                session = network; network.dataTask(with: request).resume()
            }
        }, onCancel: { self.cancel() })
    }
    private func cancel() {
        lock.lock(); cancelled = true; let network = session; lock.unlock()
        network?.invalidateAndCancel()
    }
    private func finish(_ result: Result<Data, Error>) {
        lock.lock()
        let reply = continuation, network = session
        continuation = nil; session = nil
        lock.unlock()
        reply?.resume(with: result)
        network?.finishTasksAndInvalidate()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url, url.scheme == "https", url.user == nil, url.password == nil,
              ["release-assets.githubusercontent.com", "objects.githubusercontent.com", "github.com"].contains(url.host ?? "")
        else { completionHandler(nil); return }
        var redirected = request
        redirected.setValue(nil, forHTTPHeaderField: "Authorization")
        completionHandler(redirected)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.expectedContentLength <= limit else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            completionHandler(.cancel)
            finish(.failure([401, 403, 404].contains(status) ? UpdateFailure.authentication : UpdateFailure.network))
            return
        }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard bytes.count + data.count <= limit else {
            dataTask.cancel(); finish(.failure(UpdateFailure.invalidPackage)); return
        }
        bytes.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finish(error.map { .failure($0) } ?? .success(bytes))
    }
}

struct GitHubUpdateSource {
    static let repository = "lansbe/palworld-mods"
    struct Asset: Decodable { let id: Int; let name: String; let size: Int }
    struct Release: Decodable { let tag_name: String; let draft: Bool; let prerelease: Bool; let assets: [Asset] }
    struct Candidate {
        let manifest: UpdateManifest
        let document: Data
        let signature: Data
        let asset: Asset
    }
    let token: String
    private func fetch(_ path: String, limit: Int, binary: Bool = false) async throws -> Data {
        let url = URL(string: "https://api.github.com/repos/" + Self.repository + path)!
        return try await UpdateDownload(limit: limit).fetch(url, token: token, binary: binary)
    }
    func latest(after current: String) async throws -> Candidate? {
        guard let installed = ReleaseVersion(current) else { throw UpdateFailure.invalidPackage }
        var releases: [Release] = []
        for page in 1...10 {
            let data = try await fetch("/releases?per_page=100&page=\(page)", limit: 2_097_152)
            let batch = try JSONDecoder().decode([Release].self, from: data)
            releases += batch
            if batch.count < 100 { break }
            if page == 10 { throw UpdateFailure.network }
        }
        guard let release = Self.newest(releases, after: installed) else { return nil }
        func asset(_ name: String) throws -> Asset {
            guard let item = release.assets.first(where: { $0.name == name }), item.id > 0 else { throw UpdateFailure.invalidPackage }
            return item
        }
        let document = try await download(asset("palworld-mods-update.json"), limit: 16_384)
        let signature = try await download(asset("palworld-mods-update.sig"), limit: 64)
        let manifest = try UpdateManifest.verified(document, signature: signature)
        guard "v" + manifest.version == release.tag_name else { throw UpdateFailure.invalidPackage }
        let archive = try asset(manifest.archive)
        guard archive.size == manifest.size else { throw UpdateFailure.invalidPackage }
        return Candidate(manifest: manifest, document: document, signature: signature, asset: archive)
    }
    static func newest(_ releases: [Release], after installed: ReleaseVersion) -> Release? {
        let candidates = releases.filter { release in
            guard !release.draft, !release.prerelease, release.tag_name.hasPrefix("v"),
                  let version = ReleaseVersion(String(release.tag_name.dropFirst())) else { return false }
            return version > installed
        }.sorted { ReleaseVersion(String($0.tag_name.dropFirst()))! > ReleaseVersion(String($1.tag_name.dropFirst()))! }
        return candidates.first
    }
    func download(_ asset: Asset, limit: Int) async throws -> Data {
        guard asset.size > 0, asset.size <= limit else { throw UpdateFailure.invalidPackage }
        let data = try await fetch("/releases/assets/\(asset.id)", limit: limit, binary: true)
        guard data.count == asset.size else { throw UpdateFailure.invalidPackage }
        return data
    }
}
