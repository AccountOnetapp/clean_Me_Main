import SwiftUI
import Photos
import Combine

final class SimilaritySectionsViewModel: ObservableObject {
    @Published var sections: [MediaCleanerServiceSection]
    @Published var selectedItems: Set<String> = []
    @Published var isSelectionMode: Bool = false

    let type: ScanItemType
    
    var title: String {
        return type.title
    }
    
    var hasSelectedItems: Bool {
        return !selectedItems.isEmpty
    }
    
    var selectedCount: Int {
        return selectedItems.count
    }

    init(sections: [MediaCleanerServiceSection], type: ScanItemType) {
        self.sections = sections
        self.type = type
    }
    
    func toggleSelection(for model: MediaCleanerServiceModel) {
        let itemId = model.asset.localIdentifier
        if selectedItems.contains(itemId) {
            selectedItems.remove(itemId)
        } else {
            selectedItems.insert(itemId)
        }
        
        // Автоматически выходим из режима выделения, если ничего не выбрано
        if selectedItems.isEmpty {
            isSelectionMode = false
        }
    }
    
    func isSelected(_ model: MediaCleanerServiceModel) -> Bool {
        return selectedItems.contains(model.asset.localIdentifier)
    }
    
    func selectAll() {
        selectedItems.removeAll()
        for section in sections {
            for model in section.models {
                selectedItems.insert(model.asset.localIdentifier)
            }
        }
        isSelectionMode = true
    }
    
    func deselectAll() {
        selectedItems.removeAll()
        isSelectionMode = false
    }
    
    func selectAllInSection(_ section: MediaCleanerServiceSection) {
        for model in section.models {
            selectedItems.insert(model.asset.localIdentifier)
        }
        isSelectionMode = true
    }
    
    func deselectAllInSection(_ section: MediaCleanerServiceSection) {
        for model in section.models {
            selectedItems.remove(model.asset.localIdentifier)
        }
        
        // Автоматически выходим из режима выделения, если ничего не выбрано
        if selectedItems.isEmpty {
            isSelectionMode = false
        }
    }
    
    func isAllSelectedInSection(_ section: MediaCleanerServiceSection) -> Bool {
        return section.models.allSatisfy { model in
            selectedItems.contains(model.asset.localIdentifier)
        }
    }
    
    func deleteSelected() {
           guard !selectedItems.isEmpty else { return }
           
           // 1. Получаем ассеты по их localIdentifier
           let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: Array(selectedItems), options: nil)
           
           // 2. Выполняем изменения в медиатеке
           PHPhotoLibrary.shared().performChanges({
               PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
           }) { [weak self] success, error in
               DispatchQueue.main.async {
                   if success {
                       print("✅ Successfully deleted \(self?.selectedItems.count ?? 0) items from the photo library.")
                       
                       // 3. Обновляем данные в ViewModel после успешного удаления
                       self?.removeDeletedItemsFromViewModel()
                   } else if let error = error {
                       print("❌ Error deleting assets: \(error.localizedDescription)")
                       // Обработка ошибки удаления
                   }
                   
                   // 4. Сбрасываем выбранные элементы и режим выделения
                   self?.selectedItems.removeAll()
                   self?.isSelectionMode = false
               }
           }
       }
       
       // ✅ Новый вспомогательный метод для обновления данных после удаления
       private func removeDeletedItemsFromViewModel() {
           for localIdentifier in selectedItems {
               // Ищем и удаляем элемент из каждой секции
               for i in sections.indices {
                   sections[i].models.removeAll { $0.asset.localIdentifier == localIdentifier }
               }
           }
           
           // Удаляем пустые секции, если в них больше нет фотографий
           sections.removeAll { $0.models.isEmpty }
       }
}
