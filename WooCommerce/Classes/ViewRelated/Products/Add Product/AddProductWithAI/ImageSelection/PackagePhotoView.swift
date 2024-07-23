import SwiftUI

struct PackagePhotoView: View {
    @ScaledMetric private var scale: CGFloat = 1.0

    let title: String
    let subTitle: String?
    let imageState: EditableImageViewState

    let onTapViewPhoto: () -> Void
    let onTapReplacePhoto: (() -> Void)?
    let onTapRemovePhoto: () -> Void

    init(title: String,
         subTitle: String? = nil,
         imageState: EditableImageViewState,
         onTapViewPhoto: @escaping () -> Void,
         onTapReplacePhoto: (() -> Void)? = nil,
         onTapRemovePhoto: @escaping () -> Void) {
        self.title = title
        self.subTitle = subTitle
        self.imageState = imageState
        self.onTapViewPhoto = onTapViewPhoto
        self.onTapReplacePhoto = onTapReplacePhoto
        self.onTapRemovePhoto = onTapRemovePhoto
    }

    var body: some View {
        AdaptiveStack(horizontalAlignment: .leading,
                      verticalAlignment: .center,
                      spacing: Layout.spacing) {
            EditableImageView(imageState: imageState,
                              emptyContent: {})
            .frame(width: Layout.packagePhotoSize * scale, height: Layout.packagePhotoSize * scale)
            .cornerRadius(Layout.cornerRadius)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .bodyStyle()

                if let subTitle {
                    Text(subTitle)
                        .footnoteStyle()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Menu {
                Button(Localization.viewPhoto) {
                    onTapViewPhoto()
                }
                if let onTapReplacePhoto {
                    Button(Localization.replacePhoto) {
                        onTapReplacePhoto()
                    }
                }
                Button(role: .destructive) {
                    onTapRemovePhoto()
                } label: {
                    Text(Localization.removePhoto)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: Layout.ellipisButtonSize * scale, height: Layout.ellipisButtonSize * scale)
                    .bodyStyle()
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(Layout.padding)
        .background(Color(light: Color(.systemColor(.systemGray6)),
                          dark: Color(.systemColor(.systemGray5))))
    }

    enum Layout {
        static let spacing: CGFloat = 16
        static let cornerRadius: CGFloat = 4
        static let padding = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        static let packagePhotoSize: CGFloat = 48
        static let ellipisButtonSize: CGFloat = 24
    }

    enum Localization {
        static let viewPhoto = NSLocalizedString(
            "packagePhotoView.viewPhoto",
            value: "View Photo",
            comment: "Title of button which opens the selected package photo."
        )
        static let replacePhoto = NSLocalizedString(
            "packagePhotoView.replacePhoto",
            value: "Replace Photo",
            comment: "Title of the button which opens photo selection flow to replace selected package photo."
        )
        static let removePhoto = NSLocalizedString(
            "packagePhotoView.removePhoto",
            value: "Remove Photo",
            comment: "Title of button which removes selected package photo."
        )
    }
}
