import SwiftUI
import protocol Yosemite.POSItem

struct ItemListView: View {
    @ObservedObject var viewModel: ItemSelectorViewModel

    init(viewModel: ItemSelectorViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            Text("Products")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .font(.title)
                .foregroundColor(Color.posPrimaryTexti3)
            if viewModel.isSyncingItems {
                Spacer()
                Text("Loading...")
                Spacer()
            } else {
                ScrollView {
                    ForEach(viewModel.items, id: \.productID) { item in
                        Button(action: {
                            viewModel.select(item)
                        }, label: {
                            ItemCardView(item: item)
                        })
                    }
                }
            }
        }
        .task {
            await viewModel.populatePointOfSaleItems()
        }
        .refreshable {
            await viewModel.reload()
        }
        .padding(.horizontal, 32)
        .background(Color.posBackgroundGreyi3)
    }
}

#if DEBUG
#Preview {
    ItemListView(viewModel: ItemSelectorViewModel(itemProvider: POSItemProviderPreview()))
}
#endif
