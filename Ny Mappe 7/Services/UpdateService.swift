import AppKit
import Foundation

struct UpdateStatus {
    let available: Bool
    let commitsBehind: Int
    let latestMessage: String
}

/// Sjekker om det finnes en nyere versjon i git-repoet appen ble bygget fra,
/// og kan oppdatere ved \u{00E5} pulle + kj\u{00F8}re build.sh (frakoblet, s\u{00E5} bygget overlever
/// at appen drepes og relanseres av build.sh).
///
/// Repo-sti og commit embedes i Info.plist ved bygging (NM7RepoPath / NM7GitCommit).
final class UpdateService {
    static let shared = UpdateService()
    private init() {}

    var repoPath: String? {
        guard let path = Bundle.main.infoDictionary?["NM7RepoPath"] as? String, !path.isEmpty else { return nil }
        return path
    }

    var builtCommit: String? {
        guard let commit = Bundle.main.infoDictionary?["NM7GitCommit"] as? String, !commit.isEmpty else { return nil }
        return commit
    }

    /// Sjekker p\u{00E5} bakgrunnstr\u{00E5}d. Kaller completion p\u{00E5} main. nil = kunne ikke sjekke.
    func checkForUpdate(completion: @escaping (UpdateStatus?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let result = self.checkSync()
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func checkSync() -> UpdateStatus? {
        guard let repo = repoPath,
              FileManager.default.fileExists(atPath: repo + "/.git"),
              let built = builtCommit else { return nil }

        // Hent oppdateringer fra remote (uten \u{00E5} henge p\u{00E5} auth-prompt)
        _ = runGit(["fetch", "--quiet"], in: repo)

        // Remote-commit (upstream til gjeldende branch)
        let upstream = runGit(["rev-parse", "@{u}"], in: repo)
        guard upstream.status == 0, !upstream.output.isEmpty else { return nil }
        let remoteCommit = upstream.output

        if remoteCommit == built {
            return UpdateStatus(available: false, commitsBehind: 0, latestMessage: "")
        }

        // Hvor mange commits den bygde versjonen ligger bak remote
        let countResult = runGit(["rev-list", "--count", "\(built)..\(remoteCommit)"], in: repo)
        let behind = Int(countResult.output) ?? 1
        guard behind > 0 else {
            return UpdateStatus(available: false, commitsBehind: 0, latestMessage: "")
        }

        let message = runGit(["log", "-1", "--format=%s", remoteCommit], in: repo).output
        return UpdateStatus(available: true, commitsBehind: behind, latestMessage: message)
    }

    /// Starter oppdateringen frakoblet appen, slik at bygget fullf\u{00F8}rer selv om
    /// build.sh dreper den kj\u{00F8}rende appen midt i.
    func applyUpdate() {
        guard let repo = repoPath else { return }
        let command = "nohup bash -c 'cd \"\(repo)\" && GIT_TERMINAL_PROMPT=0 /usr/bin/git pull --ff-only && ./build.sh' >/tmp/nm7-update.log 2>&1 &"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        try? process.run()
    }

    @discardableResult
    private func runGit(_ args: [String], in repo: String) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repo] + args

        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"   // feil i stedet for \u{00E5} henge p\u{00E5} passord-prompt
        process.environment = env

        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()

        do { try process.run() } catch { return (-1, "") }
        process.waitUntilExit()

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (process.terminationStatus, output)
    }
}
