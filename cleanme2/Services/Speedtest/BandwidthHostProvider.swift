import Foundation
import Combine
import os.log

/// Поставщик хостов для тестирования пропускной способности (Speedtest.net API)
public final class BandwidthHostProvider: BandwidthHostProviding {
    private let serviceURL: URL
    private let urlSession: URLSession
    private let logger = Logger(subsystem: "com.cleanme.speedtest", category: "BandwidthHostProvider")
    
    public required init(serviceURL: URL) {
        self.serviceURL = serviceURL
        self.urlSession = URLSession(configuration: .default)
    }
    
    public convenience init() {
        let defaultURL = URL(string: "https://www.speedtest.net/api/js/servers?engine=js&https_functional=true")!
        self.init(serviceURL: defaultURL)
    }
    
    public func fetchHosts(timeout: TimeInterval = 30.0) -> AnyPublisher<[BandwidthTestHost], BandwidthTestError> {
        logger.info("🌐 BandwidthHostProvider: ВОЗВРАЩАЕМ СЕРВЕР ПО УМОЛЧАНИЮ ДЛЯ США")
        
        // Создаем объект URL для конкретного сервера в США.
        let usDefaultURL = URL(string: "http://speedtest.tctelco.net:8080/")!
        
        // Создаем экземпляр BandwidthTestHost, используя новый публичный инициализатор.
        let usDefaultHost = BandwidthTestHost(
            url: usDefaultURL,
            name: "Test Server",
            country: "United States",
            countryCode: "US",
            hostAddress: "speedtest.tctelco.net:8080",
            sponsor: "TCTELCO",
            distanceKm: 0
        )
        
        // Возвращаем результат в виде паблишера, который сразу же передает созданный хост.
        return Just([usDefaultHost])
            .setFailureType(to: BandwidthTestError.self)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // todo old solution not working with http
//    public func fetchHosts(timeout: TimeInterval = 30.0) -> AnyPublisher<[BandwidthTestHost], BandwidthTestError> {
//        logger.info("🌐 BandwidthHostProvider: ПОЛУЧЕНИЕ СПИСКА ХОСТОВ")
//        logger.info("📊 Параметры: timeout=\(timeout)")
//        logger.info("🔗 URL: \(self.serviceURL)")
//        
//        var request = URLRequest(url: serviceURL, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeout)
//        request.setValue("application/json", forHTTPHeaderField: "Accept")
//        
//        logger.info("⚡ Отправка запроса на получение хостов...")
//        return urlSession.dataTaskPublisher(for: request)
//            .handleEvents(receiveOutput: { [weak self] (data, response) in
//                self?.logger.info("📡 Получен ответ от сервера: \(data.count) байт")
//                if let httpResponse = response as? HTTPURLResponse {
//                    self?.logger.info("📄 HTTP статус: \(httpResponse.statusCode)")
//                }
//            })
//            .tryMap { [self] data, response -> [BandwidthTestHost] in
//                guard let httpResponse = response as? HTTPURLResponse else {
//                    logger.error("❌ Неверный тип ответа")
//                    throw BandwidthTestError.requestFailed
//                }
//                
//                guard httpResponse.isSuccessful else {
//                    logger.error("❌ HTTP ошибка: статус \(httpResponse.statusCode)")
//                    throw BandwidthTestError.requestFailed
//                }
//                
//                guard response.isJSONContentType else {
//                    logger.error("❌ Неверный Content-Type")
//                    throw BandwidthTestError.wrongContentType
//                }
//                
//                do {
//                    let hosts = try JSONDecoder().decode([BandwidthTestHost].self, from: data)
//                    logger.info("✅ Успешно декодировано \(hosts.count) хостов")
//                    return hosts
//                } catch {
//                    logger.error("❌ Ошибка декодирования JSON: \(error.localizedDescription)")
//                    throw BandwidthTestError.invalidJSON
//                }
//            }
//            .mapError { error -> BandwidthTestError in
//                if let bandwidthError = error as? BandwidthTestError {
//                    return bandwidthError
//                } else if error is DecodingError {
//                    return .invalidJSON
//                } else {
//                    return .requestFailed
//                }
//            }
//            .receive(on: DispatchQueue.main)
//            .eraseToAnyPublisher()
//    }
    
    public func fetchHosts(maxCount: Int, timeout: TimeInterval = 30.0) -> AnyPublisher<[BandwidthTestHost], BandwidthTestError> {
        return fetchHosts(timeout: timeout)
            .map { hosts in
                Array(hosts.prefix(maxCount))
            }
            .eraseToAnyPublisher()
    }
}
