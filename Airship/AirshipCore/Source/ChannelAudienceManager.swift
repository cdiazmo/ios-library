/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UAChannelAudienceManagerProtocol)
public protocol ChannelAudienceManagerProtocol {
    var pendingAttributeUpdates : [AttributeUpdate] { get }
    
    @objc
    var pendingTagGroupUpdates : [TagGroupUpdate] { get }
        
    @objc
    var channelID: String? { get set }
    
    @objc
    var enabled: Bool { get set }
        
    @objc
    func editSubscriptionLists() -> SubscriptionListEditor
    
    @objc
    func editTagGroups(allowDeviceGroup: Bool) -> TagGroupsEditor
    
    @objc
    func editAttributes() -> AttributesEditor
    
    @objc
    @discardableResult
    func fetchSubscriptionLists(completionHandler: @escaping ([String]?, Error?) -> Void) -> Disposable
}


// NOTE: For internal use only. :nodoc:
@objc(UAChannelAudienceManager)
public class ChannelAudienceManager : NSObject, ChannelAudienceManagerProtocol {
    static let updateTaskID = "ChannelAudienceManager.update"
    static let updatesKey = "UAChannel.audienceUpdates"
    
    static let legacyPendingTagGroupsKey = "com.urbanairship.tag_groups.pending_channel_tag_groups_mutations"
    static let legacyPendingAttributesKey = "com.urbanairship.channel_attributes.registrar_persistent_queue_key"
    
    static let maxCacheTime : TimeInterval = 600 // 10 minutes

    private let dataStore: PreferenceDataStore
    private let privacyManager: PrivacyManager
    private let taskManager: TaskManagerProtocol
    private let subscriptionListClient: SubscriptionListAPIClientProtocol
    private let updateClient: ChannelBulkUpdateAPIClientProtocol
    private let notificationCenter: NotificationCenter

    private let date: AirshipDate
    private let dispatcher = UADispatcher.serial()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let updateLock = Lock()
    
    @objc
    public var pendingAttributeUpdates : [AttributeUpdate] {
        get {
            var updates : [AttributeUpdate]!
            updateLock.sync {
                updates = getUpdates().compactMap() { $0.attributeUpdates }.reduce([], +)
            }
            return updates
        }
    }
    
    @objc
    public var pendingTagGroupUpdates : [TagGroupUpdate] {
        get {
            var updates : [TagGroupUpdate]!
            updateLock.sync {
                updates = getUpdates().compactMap() { $0.tagGroupUpdates }.reduce([], +)
            }
            return updates
        }
    }
    
    private let cachedSubscriptionLists : CachedValue<[String]>
    
    @objc
    public var channelID: String? {
        didSet {
            self.enqueueTask()
        }
    }
    
    @objc
    public var enabled: Bool = false {
        didSet {
            self.enqueueTask()
        }
    }
    
    init(dataStore: PreferenceDataStore,
        taskManager: TaskManagerProtocol,
        subscriptionListClient: SubscriptionListAPIClientProtocol,
        updateClient: ChannelBulkUpdateAPIClientProtocol,
        privacyManager: PrivacyManager,
        notificationCenter: NotificationCenter,
        date: AirshipDate) {
        
        self.dataStore = dataStore;
        self.taskManager = taskManager;
        self.privacyManager = privacyManager;
        self.subscriptionListClient = subscriptionListClient
        self.updateClient = updateClient
        self.notificationCenter = notificationCenter
        self.date = date
        self.cachedSubscriptionLists = CachedValue<[String]>(date: date,
                                                             maxCacheAge: ChannelAudienceManager.maxCacheTime)
        super.init()
        
        self.taskManager.register(taskID: ChannelAudienceManager.updateTaskID, dispatcher: self.dispatcher) { [weak self] task in
            self?.handleUpdateTask(task)
        }
        
        self.migrateMutations()
        
        notificationCenter.addObserver(
            self,
            selector: #selector(checkPrivacyManager),
            name: PrivacyManager.changeEvent,
            object: nil)
        
        notificationCenter.addObserver(
            self,
            selector: #selector(enqueueTask),
            name: RuntimeConfig.configUpdatedEvent,
            object: nil)
        
        
        self.checkPrivacyManager()
    }
    
    @objc
    public convenience init(dataStore: PreferenceDataStore,
                            config: RuntimeConfig,
                            privacyManager: PrivacyManager) {
        
        self.init(dataStore: dataStore,
                  taskManager: TaskManager.shared,
                  subscriptionListClient: SubscriptionListAPIClient(config: config),
                  updateClient: ChannelBulkUpdateAPIClient(config: config),
                  privacyManager: privacyManager,
                  notificationCenter: NotificationCenter.default,
                  date: AirshipDate())
    }
    
    @objc
    public func editSubscriptionLists() -> SubscriptionListEditor {
        return SubscriptionListEditor() { updates in
            guard !updates.isEmpty else {
                return
            }
            
            guard self.privacyManager.isEnabled( .tagsAndAttributes) else {
                AirshipLogger.warn("Tags and attributes are disabled. Enable to apply subscription list edits.")
                return
            }
            
            let audienceUpdate = AudienceUpdate(subscriptionListUpdates: updates, tagGroupUpdates: [], attributeUpdates: [])
            self.addUpdate(audienceUpdate)
            self.enqueueTask()
        }
    }
    
    @objc
    public func editTagGroups(allowDeviceGroup: Bool) -> TagGroupsEditor {
        return TagGroupsEditor(allowDeviceTagGroup: allowDeviceGroup) { updates in
            guard !updates.isEmpty else {
                return
            }
            
            guard self.privacyManager.isEnabled( .tagsAndAttributes) else {
                AirshipLogger.warn("Tags and attributes are disabled. Enable to apply tag group edits.")
                return
            }
            
            let audienceUpdate = AudienceUpdate(subscriptionListUpdates: [], tagGroupUpdates: updates, attributeUpdates: [])
            self.addUpdate(audienceUpdate)
            self.enqueueTask()
        }
    }
    
    @objc
    public func editAttributes() -> AttributesEditor {
        return AttributesEditor() { updates in
            guard !updates.isEmpty else {
                return
            }
            
            guard self.privacyManager.isEnabled( .tagsAndAttributes) else {
                AirshipLogger.warn("Tags and attributes are disabled. Enable to apply attribute edits.")
                return
            }
            
            let audienceUpdate = AudienceUpdate(subscriptionListUpdates: [], tagGroupUpdates: [], attributeUpdates: updates)
            self.addUpdate(audienceUpdate)
            self.enqueueTask()
        }
    }
    
    @objc
    @discardableResult
    public func fetchSubscriptionLists(completionHandler: @escaping ([String]?, Error?) -> Void) -> Disposable {
        var callback: (([String]?, Error?) -> Void)? = completionHandler
        let disposable = Disposable() {
            callback = nil
        }
        
        self.dispatcher.dispatchAsync {
            guard let channelID = self.channelID else {
                callback?(nil, AirshipErrors.error("Channel not created yet"))
                return
            }
            
            do {
                let listIDs = try self.resolveSubscriptionLists(channelID)
                callback?(self.applyPendingSubscriptionLists(listIDs), nil)
            } catch {
                callback?(nil, error)
            }
        }
        
        return disposable
    }
    
    private func resolveSubscriptionLists(_ channelID: String) throws -> [String] {
        if let cached = self.cachedSubscriptionLists.value {
            return cached
        }
        
        var fetchResponse: (SubscriptionListFetchResponse?, Error?)
        let semaphore = Semaphore()
        self.subscriptionListClient.get(channelID: channelID) { response, error in
            fetchResponse = (response, error)
            semaphore.signal()
        }
        
        semaphore.wait()
        
        guard let response = fetchResponse.0 else {
            if let error = fetchResponse.1 {
                AirshipLogger.debug("Fetched lists failed with error: \(error)")
            } else {
                AirshipLogger.debug("Fetched lists failed")
            }

            throw AirshipErrors.error("Failed to fetch subscriptoin lists failed")
        }
        
        guard response.isSuccess, let listIDs = response.listIDs else {
            throw AirshipErrors.error("Failed to fetch subscriptoin lists with status: \(response.status)")
        }
        
        AirshipLogger.debug("Fetched lists finished with response: \(response)")
        self.cachedSubscriptionLists.value = listIDs
        return listIDs
    }
    
    private func applyPendingSubscriptionLists(_ ids: [String]) -> [String] {
        var result = ids
        if let pending = ChannelAudienceManager.collapse(self.getUpdates()) {
            pending.subscriptionListUpdates.forEach { update in
                switch(update.type) {
                case .subscribe:
                    result.append(update.listId)
                case .unsubscribe:
                    result.removeAll(where: { $0 == update.listId })
                }
            }
        }
        
        return result
    }
    @objc
    private func checkPrivacyManager() {
        if (!self.privacyManager.isEnabled(.tagsAndAttributes)) {
            updateLock.sync {
                self.dataStore.removeObject(forKey: ChannelAudienceManager.updatesKey)
            }
        }
    }
    
    @objc
    private func enqueueTask() {
        if (self.enabled && self.channelID != nil) {
            self.taskManager.enqueueRequest(taskID: ChannelAudienceManager.updateTaskID,
                                            options: TaskRequestOptions.defaultOptions)
        }
    }
    
    private func handleUpdateTask(_ task: Task)  {
        guard self.enabled && self.privacyManager.isEnabled(.tagsAndAttributes) else {
            task.taskCompleted()
            return
        }
        
        guard let channelID = self.channelID, let update = self.prepareNextUpdate() else {
            task.taskCompleted()
            return
        }

        let disposable = self.updateClient.update(channelID: channelID,
                                                  subscriptionListUpdates: update.subscriptionListUpdates,
                                                  tagGroupUpdates: update.tagGroupUpdates,
                                                  attributeUpdates: update.attributeUpdates) { response, error in
            
            if let response = response {
                AirshipLogger.debug("Update finished with response: \(response)")
                if (response.isSuccess) {
                    self.popFirstUpdate()
                    self.cachedSubscriptionLists.value = nil
                    task.taskCompleted()
                    self.enqueueTask()
                    
                    let payload : [String : Any] = [
                        Channel.audienceTagsKey: update.tagGroupUpdates,
                        Channel.audienceAttributesKey: update.attributeUpdates
                    ]
                    
                    self.notificationCenter.post(name: Channel.audienceUpdatedEvent,
                                                 object: nil,
                                                 userInfo: payload)
                    
                } else if (response.isServerError) {
                    task.taskFailed()
                } else {
                    task.taskCompleted()
                }
            } else {
                if let error = error {
                    AirshipLogger.debug("Update failed with error: \(error)")
                } else {
                    AirshipLogger.debug("Update failed")
                }
                task.taskFailed()
            }
        }
        
        task.expirationHandler = {
            disposable.dispose()
        }
    }
    
    private func addUpdate(_ update: AudienceUpdate) {
        self.updateLock.sync {
            var updates = getUpdates()
            updates.append(update)
            self.storeUpdates(updates)
        }
    }
    
    private func getUpdates() -> [AudienceUpdate] {
        var result: [AudienceUpdate]?
        updateLock.sync {
            if let data = self.dataStore.data(forKey: ChannelAudienceManager.updatesKey) {
                result = try? self.decoder.decode([AudienceUpdate].self, from: data)
            }
        }
        return result ?? []
    }
    
    private func storeUpdates(_ operations: [AudienceUpdate]) {
        updateLock.sync {
            if let data = try? self.encoder.encode(operations) {
                self.dataStore.setValue(data, forKey: ChannelAudienceManager.updatesKey)
            }
        }
    }
    
    private func popFirstUpdate() {
        updateLock.sync {
            var updates = getUpdates()
            if (!updates.isEmpty) {
                updates.removeFirst()
                storeUpdates(updates)
            }
        }
    }
    
    private func prepareNextUpdate() -> AudienceUpdate? {
        var nextUpdate: AudienceUpdate? = nil
        updateLock.sync {
            let updates = self.getUpdates()
            if let collapsed = ChannelAudienceManager.collapse(updates) {
                self.storeUpdates([collapsed])
                nextUpdate = collapsed
            } else {
                self.storeUpdates([])
            }
        }
        return nextUpdate
    }
    
    private class func collapse(_ updates: [AudienceUpdate]) -> AudienceUpdate? {
        var subscriptionListUpdates : [SubscriptionListUpdate] = []
        var tagGroupUpdates : [TagGroupUpdate] = []
        var attributeUpdates : [AttributeUpdate] = []

        updates.forEach {
            subscriptionListUpdates.append(contentsOf: $0.subscriptionListUpdates)
            tagGroupUpdates.append(contentsOf: $0.tagGroupUpdates)
            attributeUpdates.append(contentsOf: $0.attributeUpdates)
        }
        
        subscriptionListUpdates = AudienceUtils.collapse(subscriptionListUpdates)
        tagGroupUpdates = AudienceUtils.collapse(tagGroupUpdates)
        attributeUpdates = AudienceUtils.collapse(attributeUpdates)

        guard !subscriptionListUpdates.isEmpty || !tagGroupUpdates.isEmpty || !attributeUpdates.isEmpty else {
            return nil
        }
        
        return AudienceUpdate(subscriptionListUpdates: subscriptionListUpdates,
                              tagGroupUpdates: tagGroupUpdates,
                              attributeUpdates: attributeUpdates)
    }
    
    
    func migrateMutations() {
        defer {
            self.dataStore.removeObject(forKey: ChannelAudienceManager.legacyPendingTagGroupsKey)
            self.dataStore.removeObject(forKey: ChannelAudienceManager.legacyPendingAttributesKey)
        }

        if (self.privacyManager.isEnabled(.tagsAndAttributes)) {
            var pendingTagUpdates : [TagGroupUpdate]?
            var pendingAttributeUpdates : [AttributeUpdate]?
            
            if let pendingTagGroupsData = self.dataStore.data(forKey: ChannelAudienceManager.legacyPendingTagGroupsKey) {
                if let pendingTagGroups = NSKeyedUnarchiver.unarchiveObject(with: pendingTagGroupsData) as? [TagGroupsMutation] {
                    pendingTagUpdates = pendingTagGroups.map { $0.tagGroupUpdates }.reduce([], +)
                }
            }
            
            if let pendingAttributesData = self.dataStore.data(forKey: ChannelAudienceManager.legacyPendingAttributesKey) {
                if let pendingAttributes = NSKeyedUnarchiver.unarchiveObject(with: pendingAttributesData) as? [AttributePendingMutations] {
                    pendingAttributeUpdates = pendingAttributes.map { $0.attributeUpdates }.reduce([], +)
                }
            }
            
            if (pendingTagUpdates != nil || pendingAttributeUpdates != nil) {
                let update = AudienceUpdate(subscriptionListUpdates: [],
                                            tagGroupUpdates: pendingTagUpdates ?? [],
                                            attributeUpdates: pendingAttributeUpdates ?? [])
                addUpdate(update)
            }
        }
    }
}

internal struct AudienceUpdate : Codable {
    let subscriptionListUpdates : [SubscriptionListUpdate]
    let tagGroupUpdates : [TagGroupUpdate]
    let attributeUpdates : [AttributeUpdate]
}

