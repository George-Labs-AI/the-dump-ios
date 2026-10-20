import Foundation
import UIKit
import FirebaseAuth

/// Everything onboarding asks of the servers, as closures so tests can swap
/// in a fake (the same shape as `RoutineCreateClient`). The AI steps go to
/// the backend's onboarding routes; saving categories, the first note and
/// "Change" reuse the web app's routes the rest of the app already calls.
struct OnboardingClient {
    var config: () async throws -> OnboardingConfig
    var transcribe: (_ file: URL, _ kind: OnboardingTranscribeKind, _ sessionId: String, _ knownNames: [String]) async throws -> OnboardingTranscription
    var read: (_ transcript: String, _ sessionId: String) async throws -> OnboardingReadResult
    var check: (_ transcript: String, _ sessionId: String) async throws -> OnboardingCheckResult
    var draft: (OnboardingDraftRequest) async throws -> [OnboardingDraftCard]
    /// `POST /api/categories/update`; returns the saved categories.
    var saveCategories: ([Category]) async throws -> [CategoryResponse]
    /// Every category on the account, archived ones included.
    var fetchCategories: () async throws -> [CategoryResponse]
    var restoreCategory: (_ categoryId: Int) async throws -> Void
    /// Each upload returns the file uuid that `/api/file_status` answers for.
    var uploadText: (String) async throws -> String
    var uploadPhoto: (UIImage) async throws -> String
    var uploadFile: (URL) async throws -> String
    var fileStatus: (_ fileUuid: String) async throws -> FileStatusEntry?
    /// `POST /api/edit_note` with a new category.
    var moveNote: (_ organizedNoteId: String, _ categoryId: Int) async throws -> Void
    var sleep: (_ seconds: TimeInterval) async throws -> Void

    static let live = OnboardingClient(
        config: { try await OnboardingAPIClient.shared.fetchConfig() },
        transcribe: { file, kind, sessionId, knownNames in
            try await OnboardingAPIClient.shared.transcribe(
                fileURL: file, kind: kind, sessionId: sessionId, knownNames: knownNames
            )
        },
        read: { transcript, sessionId in
            try await OnboardingAPIClient.shared.read(transcript: transcript, sessionId: sessionId)
        },
        check: { transcript, sessionId in
            try await OnboardingAPIClient.shared.check(transcript: transcript, sessionId: sessionId)
        },
        draft: { try await OnboardingAPIClient.shared.draft($0) },
        saveCategories: { try await NotesService.shared.addCategories($0).categories },
        fetchCategories: { try await NotesService.shared.fetchCategories().categories },
        restoreCategory: { _ = try await NotesService.shared.restoreCategory(categoryId: $0) },
        uploadText: { text in
            let token = try await AuthService.shared.getIDToken()
            return try await UploadService.shared.uploadTextNote(content: text, idToken: token).uuid
        },
        uploadPhoto: { image in
            let token = try await AuthService.shared.getIDToken()
            let email = Auth.auth().currentUser?.email ?? ""
            return try await UploadService.shared.uploadPhoto(image: image, userEmail: email, idToken: token).uuid
        },
        uploadFile: { url in
            let token = try await AuthService.shared.getIDToken()
            let email = Auth.auth().currentUser?.email ?? ""
            return try await UploadService.shared.uploadFile(fileURL: url, userEmail: email, idToken: token).uuid
        },
        fileStatus: { try await OnboardingAPIClient.shared.fileStatus(fileUuid: $0) },
        moveNote: { noteId, categoryId in
            _ = try await NotesService.shared.editNote(noteId: noteId, categoryId: categoryId)
        },
        sleep: { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    )
}

/// The backend's voice-onboarding routes (`/api/onboarding/*` on
/// `SharedConstants.backendBaseURL`), called with the Firebase ID token, and
/// a single-note status check against the web app.
final class OnboardingAPIClient {
    static let shared = OnboardingAPIClient()

    private let backendBaseURL = SharedConstants.backendBaseURL
    private let webBaseURL = SharedConstants.baseURL
    /// The AI calls retry on the server before giving up, so they get longer
    /// than URLSession's default 60 seconds.
    private let aiTimeout: TimeInterval = 150

    private init() {}

    func fetchConfig() async throws -> OnboardingConfig {
        var request = try await authorizedRequest(url: backendBaseURL + "/api/onboarding/config", method: "GET")
        request.timeoutInterval = 30
        return try await send(request, as: OnboardingConfig.self)
    }

    func read(transcript: String, sessionId: String) async throws -> OnboardingReadResult {
        let body = OnboardingTranscriptRequest(sessionId: sessionId, transcript: transcript)
        let request = try await jsonRequest(path: "/api/onboarding/read", method: "POST", body: body)
        return try await send(request, as: OnboardingReadResult.self)
    }

    func check(transcript: String, sessionId: String) async throws -> OnboardingCheckResult {
        let body = OnboardingTranscriptRequest(sessionId: sessionId, transcript: transcript)
        let request = try await jsonRequest(path: "/api/onboarding/check", method: "POST", body: body)
        return try await send(request, as: OnboardingCheckResult.self)
    }

    func draft(_ body: OnboardingDraftRequest) async throws -> [OnboardingDraftCard] {
        let request = try await jsonRequest(path: "/api/onboarding/draft", method: "POST", body: body)
        return try await send(request, as: OnboardingDraftResponse.self).categories
    }

    /// Sends a recording to be turned into text. The audio is read into
    /// memory, posted as multipart form data, and never stored on a server.
    func transcribe(
        fileURL: URL,
        kind: OnboardingTranscribeKind,
        sessionId: String,
        knownNames: [String]
    ) async throws -> OnboardingTranscription {
        let audio = try Data(contentsOf: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"
        var fields: [(String, String)] = [("kind", kind.rawValue), ("session_id", sessionId)]
        fields += knownNames.map { ("known_names", $0) }
        let file = MultipartFile(field: "file", name: "\(kind.rawValue).m4a", type: "audio/m4a", data: audio)
        let body = Self.multipartBody(boundary: boundary, fields: fields, file: file)

        var request = try await authorizedRequest(url: backendBaseURL + "/api/onboarding/transcribe", method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return try await send(request, as: OnboardingTranscription.self)
    }

    /// One `POST /api/file_status` for the first note. The app-wide poller
    /// (`NoteStatusService`) runs every 5 seconds; screen 6 asks every 2.
    func fileStatus(fileUuid: String) async throws -> FileStatusEntry? {
        var request = try await authorizedRequest(url: webBaseURL + "/api/file_status", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        do {
            request.httpBody = try JSONEncoder().encode(FileStatusRequest(fileUuids: [fileUuid]))
        } catch {
            throw APIError.encodingFailed
        }
        let response = try await send(request, as: FileStatusResponse.self)
        return response.statuses.first { $0.fileUuid == fileUuid }
    }

    // MARK: - Building requests

    struct MultipartFile {
        let field: String
        let name: String
        let type: String
        let data: Data
    }

    static func multipartBody(boundary: String, fields: [(String, String)], file: MultipartFile) -> Data {
        var body = Data()
        for (name, value) in fields {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(file.field)\"; filename=\"\(file.name)\"\r\n".utf8))
        body.append(Data("Content-Type: \(file.type)\r\n\r\n".utf8))
        body.append(file.data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }

    private func authorizedRequest(url string: String, method: String) async throws -> URLRequest {
        let token = try await AuthService.shared.getIDToken()
        guard let url = URL(string: string) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = aiTimeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func jsonRequest<Body: Encodable>(path: String, method: String, body: Body) async throws -> URLRequest {
        var request = try await authorizedRequest(url: backendBaseURL + path, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingFailed
        }
        return request
    }

    private func send<Response: Decodable>(_ request: URLRequest, as type: Response.Type) async throws -> Response {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }
            guard (200...299).contains(http.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.from(statusCode: http.statusCode, errorResponse: errorResponse)
            }
            return try JSONDecoder().decode(Response.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
#if DEBUG
            print("[OnboardingAPIClient] Decode failed for \(request.url?.path ?? "?"): \(error)")
#endif
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
}
