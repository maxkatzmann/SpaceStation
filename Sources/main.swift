import Foundation

let notificationName = "com.nsintegermax.spacestation.event"
DistributedNotificationCenter.default().postNotificationName(
  NSNotification.Name(notificationName),
  object: nil,
  userInfo: nil,
  deliverImmediately: true
)
