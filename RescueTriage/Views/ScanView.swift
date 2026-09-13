import SwiftUI
import PhotosUI
import UIKit

struct ScanView: View {
    let declaration: SupplierDeclaration

    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var state: ScanState = .idle
    @State private var verdict: Verdict?

    private enum ScanState: Equatable {
        case idle, analysing, done
    }

    var body: some View {
        Group {
            if let verdict {
                VerdictCardView(
                    declaration: declaration,
                    verdict: verdict,
                    onOverride: { outcome in
                        store.applyOverride(outcome, to: declaration.id)
                        self.verdict?.humanOverride = outcome
                    },
                    onDone: { dismiss() }
                )
            } else {
                capture
            }
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { captured in
                image = captured
                Task { await analyse(captured) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let picked = UIImage(data: data) {
                    image = picked
                    await analyse(picked)
                }
            }
        }
    }

    private var capture: some View {
        VStack(spacing: 20) {
            preview

            if state == .analysing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking the photo against the declaration…")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.top, 6)
            } else {
                VStack(spacing: 12) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showingCamera = true } label: {
                            Label("Take a photo", systemImage: "camera.fill")
                                .font(.system(size: 16, weight: .heavy))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(RescuePalette.orange, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                            .font(.system(size: 16, weight: .heavy))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RescuePalette.navy, in: Capsule())
                            .foregroundStyle(.white)
                    }

                    if let sample = UIImage(named: sampleName) {
                        Button {
                            image = sample
                            Task { await analyse(sample) }
                        } label: {
                            Text("Use the sample photo")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(RescuePalette.muted)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            Spacer()
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
        .background(RescuePalette.cream)
    }

    private var sampleName: String {
        DemoBatch.all.first { $0.declaration.productName == declaration.productName }?
            .samplePhotoName ?? ""
    }

    @ViewBuilder
    private var preview: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(RescuePalette.paper)
                .frame(height: 240)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder").font(.system(size: 40))
                        Text(declaration.productName).font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(RescuePalette.muted)
                }
                .padding(.horizontal, 24)
        }
    }

    /// Gemini describes; the engine decides. If the call fails for any reason,
    /// the regulatory verdict still stands and is labelled partial.
    private func analyse(_ image: UIImage) async {
        state = .analysing

        let client = GeminiClient.fromStoredSettings()
        var observation = ScanObservation.unavailable
        var available = false

        if client.isConfigured, let jpeg = image.jpegForUpload() {
            do {
                observation = try await client.analyse(imageData: jpeg, declaration: declaration)
                available = true
            } catch {
                observation = .unavailable
                available = false
            }
        }

        let result = VerdictEngine.evaluate(
            declaration: declaration,
            observation: observation,
            now: Date(),
            geminiAvailable: available
        )

        store.record(declaration: declaration, verdict: result)
        verdict = result
        state = .done
    }
}

extension UIImage {
    /// Gemini does not need a 12-megapixel photo, and a smaller upload is a
    /// faster demo. Long edge 1568 px, JPEG quality 0.8.
    func jpegForUpload(maxEdge: CGFloat = 1568, quality: CGFloat = 0.8) -> Data? {
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxEdge / longest)
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: quality)
    }
}

/// UIKit camera, wrapped. SwiftUI has no native camera capture on iOS 17.
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
