import Foundation

@objc(WMFBackgroundFetcher) public protocol BackgroundFetcher: NSObjectProtocol {
    func performBackgroundFetch(_ completion: @escaping (UIBackgroundFetchResult) -> Void)
}

@objc(WMFBackgroundFetcherController) public class BackgroundFetcherController: WorkerController {
    var fetchers = PointerArray<BackgroundFetcher>()
    
    @objc public func add(_ worker: BackgroundFetcher) {
        fetchers.append(worker)
    }
    
    @objc public func performBackgroundFetch(_ completion: @escaping (UIBackgroundFetchResult) -> Void) {
        let identifier = UUID().uuidString
        delegate?.workerControllerWillStart(self, workWithIdentifier: identifier)
        fetchers.allObjects.asyncMap({ (fetcher, completion) in
            fetcher.performBackgroundFetch(completion)
        }) { (results) in
            var combinedResult = UIBackgroundFetchResult.noData
            resultLoop: for result in results {
                switch result {
                case .failed:
                    combinedResult = .failed
                    break resultLoop
                case .newData:
                    combinedResult = .newData
                default:
                    break
                }
            }
            completion(combinedResult)
            self.delegate?.workerControllerDidEnd(self, workWithIdentifier: identifier)
        }
    }
}
