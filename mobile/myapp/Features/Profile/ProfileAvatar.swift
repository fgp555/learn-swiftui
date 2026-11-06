import SwiftUI

struct ProfileAvatar: View {
    let initials: String
    let image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(.quaternary)
                    .overlay {
                        Text(initials)
                            .font(.title.bold())
                    }
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    static func loadImage(for profile: UserProfile, token: String) async -> UIImage? {
        do {
            if profile.hasUploadedAvatar {
                let data = try await AuthAPI().avatar(token: token)
                return UIImage(data: data)
            }
            if let url = profile.avatarURL {
                let (data, response) = try await URLSession.shared.data(from: url)
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    return UIImage(data: data)
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}
