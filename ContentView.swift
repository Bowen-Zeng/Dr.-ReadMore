//
//  ContentView.swift
//  Dr. ReadMore
//
//  Created by Bowen on 2025-10-30.
//

import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @State private var showFileImporter = false
    @State private var isDropping = false
    @State private var pickedFiles: [PickedFile] = []
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var showSuccessToast = false

    var body: some View {
        ZStack {
            // Background: subtle glossy white/grey
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(white: 0.98), location: 0),
                    .init(color: Color(white: 0.95), location: 0.5),
                    .init(color: Color(white: 0.99), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                // Top area: app title & short tagline
                VStack(spacing: 6) {
                    Text("Dr. ReadMore")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                    Text("Upload terms — get the highlights, the catches, and what matters.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 24)

                Spacer()

                // Center Add Box
                AddBoxView(
                    isDropping: $isDropping,
                    onTap: { showFileImporter = true },
                    onFilesPicked: { urls in
                        handlePicked(urls: urls)
                    }
                )
                .frame(maxWidth: 540)
                .padding(.horizontal, 24)

                // small hint / actions row
                HStack(spacing: 16) {
                    Button(action: { showFileImporter = true }) {
                        Label("Add document", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(PrimaryThinButtonStyle())

                    Button(action: { /* Example: show sample T&C or demo */ }) {
                        Label("Try sample", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(SecondaryThinButtonStyle())

                    Spacer()

                    if isUploading {
                        ProgressView(value: uploadProgress)
                            .frame(width: 120)
                    }
                }
                .padding(.horizontal, 20)

                // Uploaded files preview
                if !pickedFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Files ready to analyze")
                            .font(.callout).foregroundColor(.gray)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(pickedFiles) { f in
                                    FileChipView(file: f) {
                                        // remove action
                                        if let idx = pickedFiles.firstIndex(where: { $0.id == f.id }) {
                                            pickedFiles.remove(at: idx)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                Spacer()
                // footer small text
                Text("Your files are processed locally when possible; otherwise encrypted in transit.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 18)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [
                    UTType.pdf,
                    UTType.plainText,
                    UTType.rtf,
                    UTType.zip,
                    UTType("com.microsoft.word.doc") ?? .data // fallbacks
                ],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    handlePicked(urls: urls)
                case .failure(let err):
                    print("File importer error:", err.localizedDescription)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropping) { providers in
                handleDrop(providers: providers)
            }

            // small success toast
            if showSuccessToast {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Label("Uploaded", systemImage: "checkmark.seal.fill")
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(.regularMaterial)
                            .cornerRadius(12)
                            .shadow(radius: 8)
                            .padding()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { showSuccessToast = false } } }
            }
        }
    }

    // MARK: - Helpers

    private func handlePicked(urls: [URL]) {
        let new = urls.map { PickedFile(url: $0) }
        pickedFiles.append(contentsOf: new)
        // Optionally auto-upload:
        // uploadFiles(new)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var foundAny = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    DispatchQueue.main.async {
                        if let data = item as? Data,
                           let url = URL(dataRepresentation: data, relativeTo: nil) {
                            self.pickedFiles.append(PickedFile(url: url))
                        } else if let url = item as? URL {
                            self.pickedFiles.append(PickedFile(url: url))
                        }
                    }
                }
                foundAny = true
            }
        }
        return foundAny
    }

    private func uploadFiles(_ files: [PickedFile]) {
        guard !files.isEmpty else { return }
        isUploading = true
        uploadProgress = 0

        UploadManager.shared.upload(files: files.map(\.url)) { progress in
            DispatchQueue.main.async {
                uploadProgress = progress
            }
        } completion: { result in
            DispatchQueue.main.async {
                isUploading = false
                switch result {
                case .success:
                    showSuccessToast = true
                case .failure(let err):
                    // handle error (show alert, etc.)
                    print("Upload Failed:", err.localizedDescription)
                }
            }
        }
    }
}

// MARK: - AddBoxView (the center, shiny drop target)

struct AddBoxView: View {
    @Binding var isDropping: Bool
    var onTap: () -> Void
    var onFilesPicked: ([URL]) -> Void

    @State private var glow = false

    var body: some View {
        ZStack {
            // glossy rounded rectangle
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial) // glassy
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.6), Color(white: 0.97)]),
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                        .blur(radius: 0.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        .blendMode(.overlay)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.white.opacity(0.002)) // tiny sheen
                        .mask(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.0)], startPoint: .top, endPoint: .center))
                )

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(white: 0.98), Color(white: 0.93)]), startPoint: .top, endPoint: .bottom))
                        .frame(width: 68, height: 68)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

                    Image(systemName: "tray.and.arrow.up.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                }
                Text("Add a Terms & Conditions file")
                    .font(.headline)
                    .foregroundColor(.black)
                Text("Drop files here or tap to upload. We'll summarize and give you the important stuff.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 18)

                HStack(spacing: 10) {
                    Button(action: onTap) {
                        Label("Upload", systemImage: "square.and.arrow.up")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(PrimaryThinButtonStyle())

                    Button(action: { /* demo: pick sample or guide */ }) {
                        Text("How it works")
                    }
                    .buttonStyle(SecondaryThinButtonStyle())
                }
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 26)
        }
        .frame(minHeight: 250)
        .overlay(
            // pulsing outline when dragging files
            RoundedRectangle(cornerRadius: 22)
                .stroke(isDropping ? Color.blue.opacity(0.45) : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.25), value: isDropping)
        )
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - FileChip and small styles

struct FileChipView: View {
    var file: PickedFile
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.url.lastPathComponent)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(file.url.pathExtension.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 6)
    }
}

struct PrimaryThinButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(configuration.isPressed ? 0.85 : 0.9)))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
    }
}

struct SecondaryThinButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .foregroundColor(.black)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.22), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.001)))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

// MARK: - Small models

struct PickedFile: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Upload manager (simple multipart)

class UploadManager {
    static let shared = UploadManager()
    private init() {}

    /// Upload multiple file URLs to backend. Reports progress in 0.0...1.0
    func upload(files: [URL],
                progressHandler: @escaping (Double) -> Void = {_ in},
                completion: @escaping (Result<Void, Error>) -> Void) {

        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "https://YOUR_BACKEND.example.com/api/upload") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // If you have auth:
        // request.setValue("Bearer YOUR_TOKEN", forHTTPHeaderField: "Authorization")

        var body = Data()
        for fileURL in files {
            let filename = fileURL.lastPathComponent
            let mimeType = mimeTypeForPath(path: fileURL.path)

            if let fileData = try? Data(contentsOf: fileURL) {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"files[]\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                body.append(fileData)
                body.append("\r\n".data(using: .utf8)!)
            }
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let task = URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let resp = response as? HTTPURLResponse, (200..<300).contains(resp.statusCode) else {
                completion(.failure(URLError(.badServerResponse))); return
            }
            completion(.success(()))
        }

        task.resume()

        // naive progress reporting (for demo). For real progress, use URLSession with delegate.
        DispatchQueue.global().async {
            for i in 1...10 {
                Thread.sleep(forTimeInterval: 0.08)
                DispatchQueue.main.async { progressHandler(Double(i)/10.0) }
            }
        }
    }

    private func mimeTypeForPath(path: String) -> String {
        let ext = (path as NSString).pathExtension
        if ext.lowercased() == "pdf" { return "application/pdf" }
        if ["txt","text"].contains(ext.lowercased()) { return "text/plain" }
        if ["rtf"].contains(ext.lowercased()) { return "application/rtf" }
        if ["doc","docx"].contains(ext.lowercased()) { return "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }
        if ["zip"].contains(ext.lowercased()) { return "application/zip" }
        return "application/octet-stream"
    }
}

// MARK: - Preview

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .preferredColorScheme(.light)
    }
}
