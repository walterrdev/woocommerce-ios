import SwiftUI

struct ThemesPreviewView: View {
    enum PreviewDevice: String, CaseIterable {
        case desktop = "desktop"
        case tablet = "tablet"
        case mobile = "mobile"

        static var defaultDevice: PreviewDevice {
            return UIDevice.current.userInterfaceIdiom == .pad ? .tablet : .mobile
        }

        var width: CGFloat {
            switch self {
            case .desktop:
                return 1200
            case .tablet:
                return 800
            case .mobile:
                return 400
            }
        }

        static var available: [PreviewDevice] {
            return [.mobile, .tablet, .desktop]
        }

        var viewportScript: String {
            let js = """
            // remove all existing viewport meta tags - some themes included multiple, which is invalid
            document.querySelectorAll("meta[name=viewport]").forEach( e => e.remove() );
            // create our new meta element
            const viewportMeta = document.createElement("meta");
            viewportMeta.name = "viewport";
            viewportMeta.content = "width=%1$d";
            // insert the correct viewport meta tag
            document.getElementsByTagName("head")[0].append(viewportMeta);
            """

            return String(format: js, NSInteger(width))
        }
    }

    @State private var selectedDevice: PreviewDevice? = PreviewDevice.defaultDevice

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                WebView(
                    isPresented: .constant(true),
                    url: URL(string: "https://tsubakidemo.wpcomstaging.com/")!,
                    previewDevice: $selectedDevice
                )

                Divider()
                    .frame(height: Layout.dividerHeight)
                    .foregroundColor(Color(.divider))

                VStack {
                    Button(Localization.startWithThemeButton) {
                        /* todo */
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Text(String(format: Localization.themeName, "Tsubaki"))
                        .secondaryBodyStyle()
                }.padding(Layout.footerPadding)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(uiImage: .closeButton)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            self.selectedDevice = .mobile

                        } label: {
                            Text(Localization.menuMobile)
                            if self.selectedDevice == .mobile {
                                Image(systemName: "checkmark")
                            }
                        }
                        Button {
                            self.selectedDevice = .tablet

                        } label: {
                            Text(Localization.menuTablet)
                            if self.selectedDevice == .tablet {
                                Image(systemName: "checkmark")
                            }
                        }
                        Button {
                            self.selectedDevice = .desktop

                        } label: {
                            Text(Localization.menuDesktop)
                            if self.selectedDevice == .desktop {
                                Image(systemName: "checkmark")
                            }
                        }
                    } label: {
                        Image(systemName: "macbook.and.iphone")
                            .secondaryBodyStyle()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private extension ThemesPreviewView {
    private enum Layout {
        static let toolbarPadding: CGFloat = 16
        static let dividerHeight: CGFloat = 1
        static let footerPadding: CGFloat = 16
    }

    private enum Localization {
        static let menuMobile = NSLocalizedString(
            "themesPreviewView.menuMobile",
            value: "Mobile",
            comment: "Menu item: mobile"
        )
        static let menuTablet = NSLocalizedString(
            "themesPreviewView.menuTablet",
            value: "Tablet",
            comment: "Menu item: tablet"
        )

        static let menuDesktop = NSLocalizedString(
            "themesPreviewView.menuMobile",
            value: "Desktop",
            comment: "Menu item: desktop"
        )
        static let startWithThemeButton = NSLocalizedString(
            "themesPreviewView.startWithThemeButton",
            value: "Start with This Theme",
            comment: "Button in theme preview screen to pick a theme."
        )
        static let themeName = NSLocalizedString(
            "themesPreviewView.themeName",
            value: "Theme: %@",
            comment: "Name of the theme being previewed."
        )
    }
}

struct ThemesPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ThemesPreviewView()
    }
}
