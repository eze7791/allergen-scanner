import SwiftUI
import PhotosUI

struct ScanView: View {
    @Environment(APIClient.self) private var api

    @State private var image: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showingCamera = false

    @State private var recognizedLines: [String] = []
    @State private var scanResult: ScanResult?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    imagePreview

                    HStack(spacing: 12) {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        PhotosPicker(selection: $photosPickerItem, matching: .images) {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)

                    if isProcessing {
                        ProgressView("Scanning on-device…")
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    if let scanResult {
                        ScanResultView(result: scanResult)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Scan Label")
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCaptureView { captured in
                    image = captured
                    Task { await processImage(captured) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photosPickerItem) { _, newValue in
                Task { await loadPickedPhoto(newValue) }
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .frame(height: 200)
                .overlay {
                    Label("Take a photo of an ingredient label", systemImage: "text.viewfinder")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
        }
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        image = uiImage
        await processImage(uiImage)
    }

    private func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        scanResult = nil
        defer { isProcessing = false }
        do {
            let lines = try await VisionTextRecognizer.recognizeLines(in: image)
            recognizedLines = lines
            guard !lines.isEmpty else {
                errorMessage = "No text was recognized in that image. Try a clearer, well-lit photo."
                return
            }
            scanResult = try await api.scanText(lines: lines)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ScanResultView: View {
    let result: ScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if result.detectedAllergens.isEmpty {
                Label("No known allergens detected", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else {
                Label("Allergens detected", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.headline)

                ForEach(result.detectedAllergens) { allergen in
                    Text(allergen.name)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.12), in: Capsule())
                        .foregroundStyle(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ScanView()
        .environment(APIClient.shared)
}
