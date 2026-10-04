import Foundation
import AppKit

// MARK: - UpdateChecker
// Simple GitHub Releases-based update checker.
// TODO: Replace with Sparkle 2 for automatic background updates.

enum UpdateChecker {

    private static let repoAPI = "https://api.github.com/repos/h0nyik/clipmanager/releases/latest"

    static func checkForUpdates(force: Bool = false) {
        guard AppSettings.shared.checkUpdates || force else { return }

        guard let url = URL(string: repoAPI) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ClipManager/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            // /releases/latest never returns drafts or pre-releases; 404 = no stable release yet
            if (response as? HTTPURLResponse)?.statusCode == 404 {
                if force { DispatchQueue.main.async { presentInfo("Máš nejnovější verzi", "Zatím není vydaná žádná novější stabilní verze.") } }
                return
            }
            guard let data,
                  let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                if force { DispatchQueue.main.async { presentInfo("Aktualizace se nepodařilo zkontrolovat.", "Zkus to prosím později.") } }
                return
            }

            let latest = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName

            DispatchQueue.main.async {
                if isNewerVersion(latest, than: currentVersion) {
                    presentUpdateAlert(latestVersion: latest, releaseURL: release.htmlURL)
                } else if force {
                    presentInfo("Máš nejnovější verzi", "ClipManager \(currentVersion) je aktuální.")
                }
            }
        }.resume()
    }

    // MARK: - Helpers

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    private static func isNewerVersion(_ remote: String, than local: String) -> Bool {
        remote.compare(local, options: .numeric) == .orderedDescending
    }

    private static func presentInfo(_ title: String, _ message: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func presentUpdateAlert(latestVersion: String, releaseURL: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Dostupná nová verze ClipManager \(latestVersion)"
        alert.informativeText = "Stáhni aktualizaci z GitHubu."
        alert.addButton(withTitle: "Stáhnout")
        alert.addButton(withTitle: "Přeskočit")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: releaseURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - GitHub API model

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName    = "tag_name"
        case htmlURL    = "html_url"
    }
}
