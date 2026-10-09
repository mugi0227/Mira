import Foundation
import PDFKit
import UIKit

enum CalendarImportError: LocalizedError {
    case missingKey
    case unreadableImage
    case server(status: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingKey: "GeminiのAPIキーが未設定です。"
        case .unreadableImage: "画像を読み込めませんでした。"
        case .server(let status, let message): "Geminiに接続できませんでした（\(status)）：\(message)"
        case .emptyResponse: "Geminiから予定を受け取れませんでした。"
        }
    }
}

/// Reads plans off calendar screenshots or photos of a screen with Gemini,
/// asking for schema-shaped JSON so nothing has to be scraped from prose.
// PERSONAL BUILD ONLY — calls Gemini directly with the owner's key.
struct GeminiCalendarExtractor: Sendable {
    var settings: GeminiSettingsStore = .shared
    var session: URLSession = .shared

    func extract(image: Data, sourceIndex: Int, today: Date) async throws -> [ImportCandidate] {
        guard let key = settings.apiKey() else { throw CalendarImportError.missingKey }
        let model = settings.model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? GeminiSettingsStore.defaultModel
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw CalendarImportError.emptyResponse
        }
        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.body(image: image, today: today))

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw CalendarImportError.server(status: status, message: Self.errorMessage(from: data))
        }
        let page = try Self.page(fromResponse: data)
        return ImportCandidateBuilder.candidates(from: page, sourceIndex: sourceIndex)
    }

    static func page(fromResponse data: Data) throws -> ExtractedCalendarPage {
        struct Response: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { var text: String? }
                    var parts: [Part]?
                }
                var content: Content?
            }
            var candidates: [Candidate]?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        let text = response.candidates?.first?.content?.parts?.compactMap(\.text).joined() ?? ""
        guard let json = text.data(using: .utf8), !text.isEmpty else { throw CalendarImportError.emptyResponse }
        return try JSONDecoder().decode(ExtractedCalendarPage.self, from: json)
    }

    static func body(image: Data, today: Date) -> [String: Any] {
        let todayText = DateFormatter.mira("yyyy-MM-dd", locale: Locale(identifier: "en_US_POSIX")).string(from: today)
        let prompt = """
        これはカレンダー画面のスクリーンショット、またはPC画面を撮った写真です（斜め・ちらつき模様があっても読んでください）。
        画面に表示されている予定を、すべて抜き出してJSONで返してください。
        - まず画面上部の年月を読み、各日付を yyyy-MM-dd に直す。前後の月のグレーの日付も正しい年月にする。年が書かれていなければ \(todayText) に近い年。
        - 時刻が書かれていれば startTime（HH:mm）。終了時刻があれば endTime。時刻がなければ allDay を true。
        - 何日にもまたがる帯は、始まりの日を date、終わりの日を endDate にする。
        - title は画面の文字どおり。時刻の文字は title に含めない。途中で切れていれば見えている分だけにし、推測で補わない。
        - 読み取りに自信がない予定は confidence を 0.5 以下にする。
        - 予定がない日や、カレンダー以外の部分（ブラウザ、タスクバー、広告）は無視する。
        """
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "events": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "title": ["type": "STRING"],
                            "date": ["type": "STRING", "description": "yyyy-MM-dd"],
                            "endDate": ["type": "STRING", "description": "yyyy-MM-dd, multi-day only"],
                            "startTime": ["type": "STRING", "description": "HH:mm or empty"],
                            "endTime": ["type": "STRING", "description": "HH:mm or empty"],
                            "allDay": ["type": "BOOLEAN"],
                            "confidence": ["type": "NUMBER"]
                        ],
                        "required": ["title", "date", "allDay"]
                    ]
                ]
            ],
            "required": ["events"]
        ]
        return [
            "contents": [[
                "role": "user",
                "parts": [
                    ["text": prompt],
                    ["inlineData": ["mimeType": "image/jpeg", "data": image.base64EncodedString()]]
                ]
            ]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": schema,
                "temperature": 0
            ]
        ]
    }

    private static func errorMessage(from data: Data) -> String {
        struct Envelope: Decodable { struct Inner: Decodable { var message: String? }; var error: Inner? }
        return (try? JSONDecoder().decode(Envelope.self, from: data))?.error?.message ?? "不明なエラー"
    }
}

/// Prepares picked files for the model: photos are downscaled JPEGs, PDFs
/// become one image per page.
enum ImportImagePreparer {
    static let maxDimension: CGFloat = 2048

    static func jpegs(fromImageData data: Data) -> [Data] {
        guard let image = UIImage(data: data) else { return [] }
        return [jpeg(image)].compactMap { $0 }
    }

    static func jpegs(fromPDF url: URL) -> [Data] {
        guard let document = PDFDocument(url: url) else { return [] }
        return (0..<min(document.pageCount, 12)).compactMap { index in
            guard let page = document.page(at: index) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            let scale = min(2, maxDimension / max(bounds.width, bounds.height))
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let image = page.thumbnail(of: size, for: .mediaBox)
            return jpeg(image)
        }
    }

    static func jpeg(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.82)
    }
}
