import SwiftUI

enum CategoryViewType: Identifiable, Hashable {
    case contacts
    case calendar
    case similarPhotos
    case duplicates
    case blurryPhotos
    case screenshots
    case videos

    var id: String {
        switch self {
        case .contacts: return "contacts"
        case .calendar: return "calendar"
        case .similarPhotos: return "similarPhotos"
        case .duplicates: return "duplicates"
        case .blurryPhotos: return "blurryPhotos"
        case .screenshots: return "screenshots"
        case .videos: return "videos"
        }
    }
}

struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @Binding var isPaywallPresented: Bool

    @State private var presentedView: CategoryViewType?
    
    init(isPaywallPresented: Binding<Bool>) {
        self._isPaywallPresented = isPaywallPresented
        print("SCAN:TEST - ScanView init called")
    }

    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24 * scalingFactor) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack {
                        Text("SnapCleaner")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(CMColor.primaryText)

                        if viewModel.progress < 1 {
                            Text("Scanning: \(Int(viewModel.progress * 100))%")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(CMColor.secondaryText)
                                .onAppear {
                                    print("SCAN:TEST - Scanning text displayed with progress: \(viewModel.progress)")
                                }
                        } else {
                            Text(viewModel.subtitle)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(CMColor.secondaryText)
                                .onAppear {
                                    print("SCAN:TEST - Subtitle displayed: \(viewModel.subtitle)")
                                }
                        }
                    }
                }

                // Smart Scanning плашка
                smartScanningCard()

                HStack(spacing: 24 * scalingFactor) {
                    Button {
                        handleContactsButtonTap()
                    } label: {
                        getItem(
                            for: .contacts, 
                            image: contactsStateImage(), 
                            count: viewModel.contactsCount, 
                            sizeStr: contactsSizeString(), 
                            size: UIScreen.main.bounds.width / 2 - 24 * scalingFactor
                        )
                    }
                    Button {
                        handleCalendarButtonTap()
                    } label: {
                        getItem(
                            for: .calendar, 
                            image: calendarStateImage(), 
                            count: viewModel.calendarEventsCount, 
                            sizeStr: calendarSizeString(), 
                            size: UIScreen.main.bounds.width / 2 - 24 * scalingFactor
                        )
                    }
                }
                .onAppear {
                    viewModel.scanContacts()
                    viewModel.scanCalendar()
                }
                HStack(spacing: 24 * scalingFactor) {
                    Button {
                        presentedView = .similarPhotos
                    } label: {
                        getItem(
                            for: .similar,
                            image: viewModel.previews.similar,
                            count: viewModel.counts.similar,
                            sizeStr: viewModel.megabytes.similar.formatAsFileSize(),
                            size: UIScreen.main.bounds.width / 2 - 24 * scalingFactor
                        )
                    }

                    Button {
                        presentedView = .duplicates
                    } label: {
                        getItem(
                            for: .duplicates,
                            image: viewModel.previews.duplicates,
                            count: viewModel.counts.duplicates,
                            sizeStr: viewModel.megabytes.duplicates.formatAsFileSize(),
                            size: UIScreen.main.bounds.width / 2 - 24 * scalingFactor
                        )
                    }
                }
                HStack(spacing: 24 * scalingFactor) {
                    Button {
                        presentedView = .blurryPhotos
                    } label: {
                        getItem(
                            for: .blurred,
                            image: viewModel.previews.blurred,
                            count: viewModel.counts.blurred,
                            sizeStr: viewModel.megabytes.blurred.formatAsFileSize(),
                            size: UIScreen.main.bounds.width / 2 - 24 * scalingFactor
                        )
                    }

                    Button {
                        presentedView = .screenshots
                    } label: {
                        getItem(
                            for: .screenshots,
                            image: viewModel.previews.screenshots,
                            count: viewModel.counts.screenshots,
                            sizeStr: viewModel.megabytes.screenshots.formatAsFileSize(),
                            size: UIScreen.main.bounds.width / 2 - 24 * scalingFactor
                        )
                    }
                }
                HStack(spacing: 24 * scalingFactor) {
                    Button {
                        presentedView = .videos
                    } label: {
                        getItem(
                            for: .videos,
                            image: viewModel.previews.videos,
                            count: viewModel.counts.videos,
                            sizeStr: viewModel.megabytes.videos.formatAsFileSize(),
                            size: UIScreen.main.bounds.width / 2 - 24 * scalingFactor
                        )
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.bottom, 100 * scalingFactor)
        }
        .onAppear {
            print("SCAN:TEST - ScanView onAppear called")
            print("SCAN:TEST - Current viewModel.progress: \(viewModel.progress)")
            print("SCAN:TEST - Current viewModel.counts.total: \(viewModel.counts.total)")
            viewModel.onAppear()
        }
        .fullScreenCover(item: $presentedView) { viewType in
                // Здесь мы создаем нужный экран в зависимости от viewType
                switch viewType {
                case .contacts:
                    ContactsView()
                case .calendar:
                    CalendarView()
                case .similarPhotos:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .image(.similar)),
                            type: .similar
                        )
                    )
                case .duplicates:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .image(.duplicates)),
                            type: .duplicates
                        )
                    )
                case .blurryPhotos:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .image(.blurred)),
                            type: .blurred
                        )
                    )
                case .screenshots:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .image(.screenshots)),
                            type: .screenshots
                        )
                    )
                case .videos:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .video),
                            type: .videos
                        )
                    )
                }
            }
    }

    private func getItem(
        for type: ScanItemType,
        image: UIImage?,
        count: Int,
        sizeStr: String,
        size: CGFloat
    ) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .frame(width: size, height: size)
                    .scaledToFit()
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }

            VStack {
                HStack {
                    Text(type.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CMColor.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CMColor.border)
                        .cornerRadius(12)

                    Spacer()
                }

                Spacer()

                HStack {
                    Text(getItemCountText(for: type, count: count, sizeStr: sizeStr))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CMColor.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CMColor.background)
                        .cornerRadius(12)

                    Spacer()
                }
            }
            .padding(12)
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(CMColor.backgroundSecondary)
        )
        .clipped()
    }
    
    // MARK: - Helper Methods for Contacts and Calendar
    
    private func handleContactsButtonTap() {
        switch viewModel.contactsPermissionStatus {
        case .authorized:
            // Переходим на экран контактов если есть разрешения
            presentedView = .contacts
        case .denied:
            // Если разрешение отклонено, перебрасываем в настройки
            print("SCAN:TEST - Contacts permission denied, opening settings")
            viewModel.openAppSettings()
        case .notDetermined, .loading:
            // Во время загрузки или при неопределенном состоянии - ничего не делаем
            print("SCAN:TEST - Contacts button tapped but permission in progress: \(viewModel.contactsPermissionStatus)")
        }
    }
    
    private func handleCalendarButtonTap() {
        switch viewModel.calendarPermissionStatus {
        case .authorized:
            // Переходим на экран календаря если есть разрешения
            presentedView = .calendar
        case .denied:
            // Если разрешение отклонено, перебрасываем в настройки
            print("SCAN:TEST - Calendar permission denied, opening settings")
            viewModel.openAppSettings()
        case .notDetermined, .loading:
            // Во время загрузки или при неопределенном состоянии - ничего не делаем
            print("SCAN:TEST - Calendar button tapped but permission in progress: \(viewModel.calendarPermissionStatus)")
        }
    }
    
    private func contactsStateImage() -> UIImage? {
        switch viewModel.contactsPermissionStatus {
        case .notDetermined:
            return generateEmptyStateImage(systemName: "person.badge.key.fill", color: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .systemYellow : .systemOrange
            })
        case .denied:
            return generateEmptyStateImage(systemName: "person.fill.xmark", color: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .systemRed : .systemRed
            })
        case .loading:
            return generateEmptyStateImage(systemName: "person.fill", color: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .systemGray : .systemGray3
            })
        case .authorized:
            if viewModel.isContactsLoading {
                return generateEmptyStateImage(systemName: "person.fill", color: UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark ? .systemGray : .systemGray3
                })
            } else if viewModel.contactsCount == 0 {
                return generateEmptyStateImage(systemName: "person.2.fill", color: UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark ? .systemBlue : .systemBlue
                })
            } else {
                return generateEmptyStateImage(systemName: "person.crop.circle.fill", color: UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark ? .systemBlue : .systemBlue
                })
            }
        }
    }
    
    private func calendarStateImage() -> UIImage? {
        switch viewModel.calendarPermissionStatus {
        case .notDetermined:
            return generateEmptyStateImage(systemName: "calendar.badge.plus", color: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .systemYellow : .systemOrange
            })
        case .denied:
            return generateEmptyStateImage(systemName: "calendar.badge.exclamationmark", color: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .systemRed : .systemRed
            })
        case .loading:
            return generateEmptyStateImage(systemName: "calendar", color: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .systemGray : .systemGray3
            })
        case .authorized:
            if viewModel.isCalendarLoading {
                return generateEmptyStateImage(systemName: "calendar", color: UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark ? .systemGray : .systemGray3
                })
            } else if viewModel.calendarEventsCount == 0 {
                return generateEmptyStateImage(systemName: "calendar.circle.fill", color: UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark ? .systemBlue : .systemBlue
                })
            } else {
                return generateEmptyStateImage(systemName: "calendar.badge.clock", color: UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark ? .systemGreen : .systemGreen
                })
            }
        }
    }
    
    private func contactsSizeString() -> String {
        return viewModel.contactsCount > 0 ? "" : ""
    }
    
    private func calendarSizeString() -> String {
        return viewModel.calendarEventsCount > 0 ? "" : ""
    }
    
    private func generateEmptyStateImage(systemName: String, color: UIColor) -> UIImage? {
        // Создаем прозрачное изображение с иконкой по центру
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .regular, scale: .large)
        let image = UIImage(systemName: systemName, withConfiguration: config)
        return image?.withTintColor(color, renderingMode: .alwaysOriginal)
    }
    
    private func getItemCountText(for type: ScanItemType, count: Int, sizeStr: String) -> String {
        switch type {
        case .contacts:
            switch viewModel.contactsPermissionStatus {
            case .notDetermined:
                return "Requesting permission..."
            case .denied:
                return "Tap to open Settings"
            case .loading:
                return "Requesting access..."
            case .authorized:
                if viewModel.isContactsLoading {
                    return "Loading contacts..."
                } else if count == 0 {
                    return "No contacts"
                } else {
                    return "\(count) contacts"
                }
            }
        case .calendar:
            switch viewModel.calendarPermissionStatus {
            case .notDetermined:
                return "Requesting permission..."
            case .denied:
                return "Tap to open Settings"
            case .loading:
                return "Requesting access..."
            case .authorized:
                if viewModel.isCalendarLoading {
                    return "Loading events..."
                } else if count == 0 {
                    return "No events"
                } else {
                    return "\(count) events"
                }
            }
        case .similar, .duplicates, .blurred, .screenshots, .videos:
            if count == 0 {
                return "No items"
            } else {
                return "\(count) items • \(sizeStr)"
            }
        }
    }
    
    // MARK: - Smart Scanning Card
    
    @ViewBuilder
    private func smartScanningCard() -> some View {
        HStack(spacing: 16) {
            // Иконка слева
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                VStack(spacing: -2) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                        .offset(x: 8, y: -4)
                }
            }
            
            // Контент справа
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart scanning")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("The application scans the gallery\nand groups photos by categories")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                }
                
                // Кнопка Start smart scanning
                Button(action: {
                    // Действие при нажатии на кнопку
                    print("Start smart scanning pressed")
                    // Можно добавить логику принудительного пересканирования
                    viewModel.onAppear()
                }) {
                    HStack(spacing: 8) {
                        Text("Start smart scanning")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(CMColor.backgroundSecondary)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .padding(.horizontal, 8)
    }
}
