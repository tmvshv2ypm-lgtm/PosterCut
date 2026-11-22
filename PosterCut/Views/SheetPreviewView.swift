import SwiftUI

/// Built-in sheet-by-sheet Liquid Glass Print Previewer allowing exact inspection of every cut sheet,
/// zoom/pan, horizontal filmstrip navigation, direct AirPrint, and 1-tap PDF sharing.
struct SheetPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PosterStudioViewModel
    @ObservedObject private var themeManager = PosterThemeManager.shared

    @State private var preparedJob: PreparedPrintJob?
    @State private var selectedPage: Int = 0
    @State private var renderedPageImage: UIImage?
    @State private var thumbnailCache: [Int: UIImage] = [:]
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientLiquidBackdrop()

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.15)
                        Text(L10n.tr("preview_preparing"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                } else if let job = preparedJob {
                    VStack(spacing: 0) {
                        // Zoomable full sheet stage
                        GeometryReader { geo in
                            ZStack {
                                if let img = renderedPageImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                        .shadow(color: .black.opacity(0.28), radius: 14, y: 7)
                                        .scaleEffect(zoom)
                                        .padding(18)
                                        .frame(width: geo.size.width, height: geo.size.height)
                                } else {
                                    ProgressView()
                                }
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { val in
                                        zoom = max(1.0, min(4.0, lastZoom * val))
                                    }
                                    .onEnded { _ in
                                        lastZoom = zoom
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    zoom = zoom > 1.2 ? 1.0 : 2.2
                                    lastZoom = zoom
                                }
                            }
                        }

                        // Page indicator + Prev / Next pill
                        HStack(spacing: 14) {
                            Button {
                                selectPage(max(0, selectedPage - 1))
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.subheadline.weight(.bold))
                                    .frame(width: 34, height: 34)
                                    .liquidGlassCircle(interactive: true)
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedPage <= 0)

                            VStack(spacing: 1) {
                                Text(L10n.fmt("preview_page_of_fmt", selectedPage + 1, job.totalPages))
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                Text(job.pageLabel(for: selectedPage))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .liquidGlassCapsule(interactive: false)

                            Button {
                                selectPage(min(job.totalPages - 1, selectedPage + 1))
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.bold))
                                    .frame(width: 34, height: 34)
                                    .liquidGlassCircle(interactive: true)
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedPage >= job.totalPages - 1)
                        }
                        .padding(.bottom, 10)

                        // Bottom horizontal sheet filmstrip
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(0..<job.totalPages, id: \.self) { idx in
                                        let isCurrent = idx == selectedPage
                                        Button {
                                            selectPage(idx)
                                        } label: {
                                            VStack(spacing: 4) {
                                                Group {
                                                    if let thumb = thumbnailCache[idx] {
                                                        Image(uiImage: thumb)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                    } else {
                                                        Rectangle()
                                                            .fill(Color.white.opacity(0.92))
                                                            .overlay(ProgressView().scaleEffect(0.6))
                                                    }
                                                }
                                                .frame(width: 56, height: 72)
                                                .background(Color.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                        .strokeBorder(
                                                            isCurrent ? themeManager.primaryAccent : Color.primary.opacity(0.16),
                                                            lineWidth: isCurrent ? 2.4 : 0.8
                                                        )
                                                )

                                                Text(job.pageLabel(for: idx))
                                                    .font(.system(size: 10, weight: isCurrent ? .bold : .medium))
                                                    .foregroundStyle(isCurrent ? themeManager.primaryAccent : .secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .id(idx)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .liquidGlassRoundedRect(cornerRadius: 22, interactive: false)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                            .onChange(of: selectedPage) { _, next in
                                withAnimation {
                                    proxy.scrollTo(next, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr("preview_window_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("btn_close")) {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let job = preparedJob {
                        Button {
                            viewModel.printDirectlyWithAirPrint(preparedJob: job)
                        } label: {
                            Label(L10n.tr("ios_airprint"), systemImage: "printer.fill")
                        }
                        .tint(themeManager.primaryAccent)

                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                viewModel.exportAndShare()
                            }
                        } label: {
                            Label(L10n.tr("step_export"), systemImage: "square.and.arrow.up")
                        }
                        .tint(themeManager.primaryAccent)
                    }
                }
            }
            .task {
                await loadJob()
            }
        }
    }

    private func loadJob() async {
        guard let raw = viewModel.rawImage else {
            isLoading = false
            errorMessage = L10n.tr("err_load_image")
            return
        }
        let cfg = viewModel.config
        do {
            let job = try await Task.detached(priority: .userInitiated) {
                try PosterEngine.preparePrintJob(rawImage: raw, config: cfg)
            }.value
            await MainActor.run {
                self.preparedJob = job
                self.isLoading = false
                self.selectPage(0)
            }
            // Generate lightweight filmstrip thumbnails asynchronously
            let total = job.totalPages
            for idx in 0..<total {
                if Task.isCancelled { break }
                let thumb = await Task.detached(priority: .utility) {
                    PosterEngine.renderSheetPreviewImage(job: job, pageIndex: idx, maxDim: 180.0)
                }.value
                await MainActor.run {
                    self.thumbnailCache[idx] = thumb
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func selectPage(_ index: Int) {
        guard let job = preparedJob, index >= 0, index < job.totalPages else { return }
        selectedPage = index
        zoom = 1.0
        lastZoom = 1.0
        Task.detached(priority: .userInitiated) {
            let img = PosterEngine.renderSheetPreviewImage(job: job, pageIndex: index, maxDim: 1400.0)
            await MainActor.run {
                if self.selectedPage == index {
                    self.renderedPageImage = img
                }
            }
        }
    }
}
