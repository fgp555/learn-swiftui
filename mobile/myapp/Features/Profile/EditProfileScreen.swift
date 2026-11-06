import ImageIO
import PhotosUI
import SwiftUI

struct EditProfileScreen: View {
    let profile: UserProfile
    let currentAvatar: UIImage?
    let token: String
    let onSave: (UserProfile) -> Void
    let onExpired: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var preparedPhoto: PhotosPickerItem?
    @State private var avatar: Data?
    @State private var removeAvatar = false
    @State private var isLoadingPhoto = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(profile: UserProfile, currentAvatar: UIImage?, token: String, onSave: @escaping (UserProfile) -> Void, onExpired: @escaping () -> Void) {
        self.profile = profile
        self.currentAvatar = currentAvatar
        self.token = token
        self.onSave = onSave
        self.onExpired = onExpired
        _name = State(initialValue: profile.displayName)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && trimmedName.unicodeScalars.count <= 60 &&
            !isSaving && !isLoadingPhoto && selectedPhoto == preparedPhoto
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Nombre visible", text: $name)
                        .textContentType(.name)
                }

                Section("Foto") {
                    avatarPreview
                        .frame(maxWidth: .infinity)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Elegir foto", systemImage: "photo")
                    }

                    if isLoadingPhoto {
                        ProgressView("Preparando foto…")
                    }

                    if avatar != nil || selectedPhoto != nil ||
                        (!removeAvatar && (profile.avatarURL != nil || profile.hasUploadedAvatar)) {
                        Button("Quitar foto", role: .destructive) {
                            selectedPhoto = nil
                            preparedPhoto = nil
                            avatar = nil
                            isLoadingPhoto = false
                            removeAvatar = true
                            errorMessage = nil
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .disabled(isSaving)
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Guardando…" : "Guardar", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .task(id: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            await loadPhoto(item)
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let avatar, let image = UIImage(data: avatar) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .accessibilityHidden(true)
        } else if removeAvatar {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        } else {
            ProfileAvatar(initials: profile.initials, image: currentAvatar)
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        isLoadingPhoto = true
        avatar = nil
        preparedPhoto = nil
        errorMessage = nil
        defer {
            if selectedPhoto == item { isLoadingPhoto = false }
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try Task.checkCancellation()
            guard selectedPhoto == item else { return }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 512
                  ] as CFDictionary),
                  let jpeg = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.8),
                  jpeg.count <= 1024 * 1024 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            avatar = jpeg
            preparedPhoto = item
            removeAvatar = false
        } catch {
            if !Task.isCancelled && selectedPhoto == item {
                errorMessage = "No se pudo preparar la foto. Elige otra o quítala."
            }
        }
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil

        Task {
            defer { isSaving = false }
            do {
                let updated = try await AuthAPI().updateProfile(
                    name: trimmedName, avatar: avatar, removeAvatar: removeAvatar, token: token
                )
                onSave(updated)
                dismiss()
            } catch AuthAPI.RequestError.invalidSession {
                dismiss()
                onExpired()
            } catch {
                errorMessage = "No se pudo guardar el perfil. Inténtalo de nuevo."
            }
        }
    }
}
