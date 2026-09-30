import PhotosUI
import SwiftUI
import UIKit

/** The avatar photo the user picked, kept on this device as a small square JPEG. */
enum AvatarPhoto {
    private static var url: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appending(path: "avatar.jpg")
    }

    static func load() -> UIImage? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /** Crops to the centre square and scales to 400 px, so the file stays around 40 KB. */
    static func save(_ image: UIImage) {
        let side = min(image.size.width, image.size.height)
        let crop = CGRect(x: (image.size.width - side) / 2, y: (image.size.height - side) / 2, width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: format).image { _ in
            image.draw(in: CGRect(x: -crop.minX * 400 / side, y: -crop.minY * 400 / side,
                                  width: image.size.width * 400 / side, height: image.size.height * 400 / side))
        }
        guard let url, let data = square.jpegData(compressionQuality: 0.8) else { return }
        do { try data.write(to: url, options: .atomic) } catch { print("Avatar save failed: \(error.localizedDescription)") }
    }

    static func remove() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

/**
 * A round avatar: the user's own photo, else their Google photo, else their initials, else a
 * person glyph. `version` changes when the local photo does, so the view reloads it.
 */
struct AvatarImage: View {
    @Environment(AccountStore.self) private var account
    var size: CGFloat
    var version: Int = 0

    var body: some View {
        let photo = AvatarPhoto.load()
        ZStack {
            Circle().fill(ServoMapColor.ink)
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else if let picture = account.account?.picture, let url = URL(string: picture) {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { fallback }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .id(version)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var fallback: some View {
        if let initials = account.initials {
            Text(initials).font(.system(size: size * 0.36, weight: .bold)).foregroundStyle(ServoMapColor.surface)
        } else {
            Image(systemName: "person.fill").font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(ServoMapColor.surface)
        }
    }
}

/** The avatar in the You header: tap to choose a photo from the library, or remove it. */
struct EditableAvatar: View {
    @State private var item: PhotosPickerItem?
    @State private var version = 0
    @State private var hasPhoto = AvatarPhoto.load() != nil

    var body: some View {
        Menu {
            PhotosPicker(selection: $item, matching: .images) { Label(hasPhoto ? "Choose another photo" : "Choose a photo", systemImage: "photo") }
            if hasPhoto {
                Button("Remove photo", systemImage: "trash", role: .destructive) {
                    AvatarPhoto.remove(); hasPhoto = false; version += 1
                }
            }
        } label: {
            AvatarImage(size: 64, version: version)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ServoMapColor.ink)
                        .frame(width: 22, height: 22)
                        .background(ServoMapColor.surface, in: Circle())
                        .overlay(Circle().strokeBorder(ServoMapColor.line))
                }
        }
        .accessibilityLabel("Profile photo")
        .onChange(of: item) {
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    AvatarPhoto.save(image)
                    hasPhoto = true
                    version += 1
                    NotificationCenter.default.post(name: .avatarChanged, object: nil)
                }
                self.item = nil
            }
        }
    }
}

extension Notification.Name {
    /** Posted when the local avatar photo changes, so the map's avatar button reloads it. */
    static let avatarChanged = Notification.Name("ServoMapAvatarChanged")
}
