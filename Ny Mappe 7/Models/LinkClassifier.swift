import Foundation

/// Kjenner igjen kopiert tekst som en ren lenke og ruter den til riktig auto-gruppe.
///
/// Brukes av clipboard-fangsten: når en lenke kopieres, havner den automatisk
/// i en dedikert gruppe i stedet for aktiv mål-gruppe. YouTube, GitHub og
/// Hugging Face får sine egne grupper; alle andre lenker samles i "Linker".
enum LinkClassifier {

    /// Navnene på auto-gruppene. Brukes for oppslag/opprettelse i view-modellen.
    enum Group: String, CaseIterable {
        case youtube = "YouTube"
        case github = "GitHub"
        case huggingface = "Hugging Face"
        case other = "Linker"
    }

    /// Returnerer gruppa en kopiert lenke skal havne i, eller nil hvis teksten
    /// ikke ser ut som én enkelt lenke.
    static func group(for text: String) -> Group? {
        guard let host = host(for: text) else { return nil }

        if host == "youtu.be" || host.hasSuffix(".youtu.be") || host.contains("youtube.com") {
            return .youtube
        }
        if host == "github.com" || host.hasSuffix(".github.com") || host.contains("githubusercontent.com") {
            return .github
        }
        if host == "hf.co" || host == "huggingface.co" || host.hasSuffix(".huggingface.co") {
            return .huggingface
        }
        return .other
    }

    /// Trekker ut host fra en tekst som er én enkelt URL.
    /// nil hvis teksten inneholder mellomrom/linjeskift (= ikke en kopiert lenke)
    /// eller mangler http(s)://- eller www.-prefiks.
    static func host(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Må være ett enkelt token — en lenke kopiert alene, ikke en setning med en URL i.
        guard !trimmed.isEmpty,
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }

        let lower = trimmed.lowercased()
        let normalized: String
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            normalized = trimmed
        } else if lower.hasPrefix("www.") {
            normalized = "https://" + trimmed
        } else {
            return nil
        }

        guard let comps = URLComponents(string: normalized),
              let host = comps.host?.lowercased(),
              host.contains(".") else { return nil }
        return host
    }
}
