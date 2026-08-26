import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 20) {
                    targetCard
                    dropZone
                    if !model.items.isEmpty { results }
                    if let summary = model.cleanupSummary { cleanupBanner(summary) }
                }
                .padding(24)
            }
            Divider()
            footer
        }
        .frame(minWidth: 820, minHeight: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $model.isChoosingSDCard) {
            VolumePickerView()
                .environmentObject(model)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("BrickDrop").font(.title2.bold())
                Text("ROM imports, sorted and cleaned").foregroundStyle(.secondary)
            }
            Spacer()
            if model.isWorking { ProgressView().controlSize(.small) }
            Button("Clean Metadata Now", systemImage: "sparkles") { model.cleanMetadataNow() }
                .disabled(model.sdRoot == nil || model.isWorking)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var targetCard: some View {
        HStack(spacing: 14) {
            Image(systemName: model.sdRoot == nil ? "sdcard" : "sdcard.fill")
                .font(.system(size: 24))
                .foregroundStyle(model.sdRoot == nil ? Color.secondary : Color.green)
                .frame(width: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.sdRoot?.lastPathComponent ?? "No SD card selected").font(.headline)
                Text(model.sdRoot?.path ?? "Select the mounted Brick Pro card once; BrickDrop remembers it securely.")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if model.sdRoot != nil {
                Button("Eject", systemImage: "eject.fill") { model.ejectSDCard() }
                    .disabled(!model.canEject)
            }
            Button(model.sdRoot == nil ? "Choose SD Card…" : "Change…") { model.chooseSDCard() }
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
    }

    private var dropZone: some View {
        VStack(spacing: 14) {
            Image(systemName: model.isTargeted ? "arrow.down.circle.fill" : "square.and.arrow.down")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(model.isTargeted ? .white : (model.sdRoot == nil ? Color.secondary : Color.accentColor))
            Text(model.isTargeted ? "Drop to add to queue" : (model.items.isEmpty ? "Drop ROM files or folders here" : "Drop more ROMs to add to the queue"))
                .font(.title3.weight(.semibold))
            Text("Each drop is added to the queue. BrickDrop copies everything together only when you click Import.")
                .multilineTextAlignment(.center).foregroundStyle(model.isTargeted ? .white.opacity(0.85) : .secondary)
                .frame(maxWidth: 520)
            if model.sdRoot == nil {
                Text("Choose an SD card first").font(.caption.weight(.medium)).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 230)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(model.isTargeted ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(model.isTargeted ? Color.white.opacity(0.7) : Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [9, 7]))
                )
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $model.isTargeted) { model.acceptProviders($0) }
        .animation(.easeOut(duration: 0.15), value: model.isTargeted)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import queue").font(.headline)
                    Text("Add files over multiple drops. Nothing is copied until you click Import.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(model.items.count) file\(model.items.count == 1 ? "" : "s")")
                    .font(.caption.weight(.medium)).padding(.horizontal, 9).padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
            }

            LazyVStack(spacing: 1) {
                ForEach(model.items) { item in resultRow(item) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2)))
        }
    }

    private func resultRow(_ item: ImportItem) -> some View {
        HStack(spacing: 12) {
            statusIcon(item.status)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.sourceURL.lastPathComponent).font(.body.weight(.medium)).lineLimit(1)
                Text(item.destinationURL.map { compactDestination($0) } ?? item.detail)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 12)
            if item.status == .needsChoice {
                Menu("Choose System") {
                    ForEach(item.candidateSystems) { system in
                        Button(system.displayName) { model.assign(system, to: item) }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            } else if let system = item.system {
                Text(system.folderName)
                    .font(.caption.bold()).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(.quaternary, in: Capsule())
            }
            Text(item.status.rawValue)
                .font(.caption).foregroundStyle(statusColor(item.status)).frame(width: 68, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .help(item.detail)
    }

    private var footer: some View {
        HStack {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            Text(model.message).font(.callout).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            if !model.items.isEmpty {
                Toggle("Replace existing files", isOn: $model.overwriteExisting)
                    .toggleStyle(.checkbox).controlSize(.small)
                Button("Clear Queue") { model.clearResults() }.disabled(model.isWorking)
                Button("Import \(model.readyCount) File\(model.readyCount == 1 ? "" : "s")", systemImage: "arrow.right.circle.fill") {
                    model.importFiles()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canImport)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
    }

    private func cleanupBanner(_ text: String) -> some View {
        Label(text, systemImage: "sparkles")
            .font(.callout).frame(maxWidth: .infinity, alignment: .leading)
            .padding(12).background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func compactDestination(_ url: URL) -> String {
        if let range = url.path.range(of: "/Roms/") { return String(url.path[range.lowerBound...].dropFirst()) }
        return url.path
    }

    @ViewBuilder private func statusIcon(_ status: ImportStatus) -> some View {
        switch status {
        case .ready, .preview: Image(systemName: "arrow.right.circle.fill").foregroundStyle(.blue)
        case .needsChoice: Image(systemName: "questionmark.circle.fill").foregroundStyle(.orange)
        case .copied: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .skipped: Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }

    private func statusColor(_ status: ImportStatus) -> Color {
        switch status {
        case .copied: .green
        case .failed: .red
        case .needsChoice: .orange
        default: .secondary
        }
    }
}

private struct VolumePickerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: MountedVolume.ID?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Choose a removable volume")
                        .font(.title2.bold())
                    Spacer()
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        model.refreshVolumes()
                        selectFirstVolumeIfNeeded()
                    }
                }
                Text("Select the SD card or external drive used by your Brick Pro.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)

            Divider()

            Group {
                if model.availableVolumes.isEmpty {
                    ContentUnavailableView(
                        "No removable volumes found",
                        systemImage: "externaldrive.badge.questionmark",
                        description: Text("Connect and mount an SD card or external drive, then click Refresh.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(model.availableVolumes) { volume in
                                volumeRow(volume)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Text("Internal disks are hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) {
                    model.isChoosingSDCard = false
                }
                Button("Use This Volume") {
                    guard let volume = selectedVolume else { return }
                    model.selectSDCard(volume)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedVolume == nil)
            }
            .padding(16)
        }
        .frame(width: 560, height: 440)
        .onAppear {
            selectFirstVolumeIfNeeded()
        }
        .onChange(of: model.availableVolumes) {
            selectFirstVolumeIfNeeded()
        }
    }

    private var selectedVolume: MountedVolume? {
        model.availableVolumes.first { $0.id == selection }
    }

    private func volumeRow(_ volume: MountedVolume) -> some View {
        Button {
            selection = volume.id
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(selection == volume.id ? Color.accentColor : .secondary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(volume.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text(volume.formatDescription)
                        Text("•")
                        Text(volume.capacityDescription)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    Text(volume.url.path)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Image(systemName: selection == volume.id ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selection == volume.id ? Color.accentColor : .secondary)
            }
            .padding(14)
            .contentShape(Rectangle())
            .background(
                selection == volume.id ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selection == volume.id ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func selectFirstVolumeIfNeeded() {
        if let selection, model.availableVolumes.contains(where: { $0.id == selection }) {
            return
        }
        selection = model.availableVolumes.first?.id
    }
}
