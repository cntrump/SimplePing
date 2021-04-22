/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A view controller for testing SimplePing on iOS.
 */

import UIKit

class MainViewController: UITableViewController, SimplePingDelegate {

    let hostName = "www.apple.com"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = hostName
    }

    var pinger: SimplePing?
    var sendTimer: Timer?
    
    /// Called by the table view selection delegate callback to start the ping.
    
    func start(forceIPv4: Bool, forceIPv6: Bool) {
        pingerWillStart()

        NSLog("start")

        let pinger = SimplePing(hostName: hostName)
        self.pinger = pinger

        // By default we use the first IP address we get back from host resolution (.Any) 
        // but these flags let the user override that.
            
        if (forceIPv4 && !forceIPv6) {
            pinger.addressStyle = .icmPv4
        } else if (forceIPv6 && !forceIPv4) {
            pinger.addressStyle = .icmPv6
        }

        pinger.delegate = self
        pinger.start()
    }

    /// Called by the table view selection delegate callback to stop the ping.
    
    func stop() {
        NSLog("stop")
        pinger?.stop()
        pinger = nil

        sendTimer?.invalidate()
        sendTimer = nil
        
        pingerDidStop()
    }

    /// Sends a ping.
    ///
    /// Called to send a ping, both directly (as soon as the SimplePing object starts up) and 
    /// via a timer (to continue sending pings periodically).
    
    @objc func sendPing() {
        pinger!.send(with: nil)
    }

    // MARK: pinger delegate callback
    
    func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
        NSLog("pinging %@", MainViewController.displayAddressForAddress(address))
        
        // Send the first ping straight away.
        
        sendPing()

        // And start a timer to send the subsequent pings.
        
        assert(sendTimer == nil)
        sendTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(MainViewController.sendPing), userInfo: nil, repeats: true)
    }
    
    func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        NSLog("failed: %@", MainViewController.shortErrorFromError(error))
        
        stop()
    }
    
    func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        NSLog("#%u sent", sequenceNumber)
    }
    
    func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {
        NSLog("#%u send failed: %@", sequenceNumber, MainViewController.shortErrorFromError(error))
    }
    
    func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        NSLog("#%u received, size=%zu", sequenceNumber, packet.count)
    }
    
    func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
        NSLog("unexpected packet, size=%zu", packet.count)
    }
    
    // MARK: utilities
    
    /// Returns the string representation of the supplied address.
    ///
    /// - parameter address: Contains a `(struct sockaddr)` with the address to render.
    ///
    /// - returns: A string representation of that address.

    static func displayAddressForAddress(_ address: Data) -> String {
        var hostStr = [Int8](repeating: 0, count: Int(NI_MAXHOST));
        
        let success = getnameinfo(
            address.withUnsafeBytes { (ptr) -> UnsafePointer<sockaddr> in
                ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
            },
            socklen_t(address.count),
            &hostStr, 
            socklen_t(hostStr.count), 
            nil, 
            0, 
            NI_NUMERICHOST
        ) == 0
        let result: String
        if success {
            result = String(cString: hostStr)
        } else {
            result = "?"
        }
        return result
    }

    /// Returns a short error string for the supplied error.
    ///
    /// - parameter error: The error to render.
    ///
    /// - returns: A short string representing that error.

    static func shortErrorFromError(_ error: Error) -> String {
        let error = error as NSError

        if error.domain == kCFErrorDomainCFNetwork as String, error.code == Int(CFNetworkErrors.cfHostErrorUnknown.rawValue) {
            if let failureObj = error.userInfo[kCFGetAddrInfoFailureKey as String] {
                if let failureNum = failureObj as? NSNumber {
                    if failureNum.intValue != 0 {
                        let f = gai_strerror(failureNum.int32Value)
                        if f != nil {
                            return String(cString: f!, encoding: .utf8)!
                        }
                    }
                }
            }
        }
        if let result = error.localizedFailureReason {
            return result
        }
        return error.localizedDescription
    }
    
    // MARK: table view delegate callback
    
    @IBOutlet var forceIPv4Cell: UITableViewCell!
    @IBOutlet var forceIPv6Cell: UITableViewCell!
    @IBOutlet var startStopCell: UITableViewCell!

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath : IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        switch cell {
        case forceIPv4Cell, forceIPv6Cell:
            cell.accessoryType = cell.accessoryType == .none ? .checkmark : .none
        case startStopCell:
            if pinger == nil {
                let forceIPv4 = forceIPv4Cell.accessoryType != .none
                let forceIPv6 = forceIPv6Cell.accessoryType != .none
                start(forceIPv4: forceIPv4, forceIPv6: forceIPv6)
            } else {
                stop()
            }
        default:
            fatalError()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func pingerWillStart() {
        startStopCell.textLabel!.text = "Stop…"
    }
    
    func pingerDidStop() {
        startStopCell.textLabel!.text = "Start…"
    }
}
