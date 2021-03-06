//
//  MonitoringViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 07/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2019 Alexey Sirotkin. All rights reserved.
//


import UIKit
import CoreLocation
#if TARGET_OS_IOS
import FirebaseAnalytics
#endif

class MonitoringViewController: UIViewController, UIActionSheetDelegate/*, RMMapViewDelegate*/{
    
    required init(coder aDecoder: NSCoder) {
        
        log = LogQueue.sharedLogQueue
        connectionManager = ConnectionManager.sharedConnectionManager
        sendingManger = SendingManager.sharedSendingManager
        groupManager = GroupManager.sharedGroupManager

        super.init(coder: aDecoder)!
    }

    var connectionManager: ConnectionManager
    var sendingManger: SendingManager
    var sessionTimer: SessionTimer?
    let groupManager: GroupManager
   
    var log: LogQueue
    var isMonitoringOn = false

    var isSessionPaused = false
    var isTracked = true
    
    var onMessageOfTheDayUpdated: ObserverSetEntry<(Int, String)>?
    var onSessionPaused: ObserverSetEntry<(Int)>?
    var onSessionStarted: ObserverSetEntry<(Int)>?
    var onGroupListUpdated: ObserverSetEntry<[Group]>?
    
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var trackerID: UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var avgSpeedLabel: UILabel!
    @IBOutlet weak var MDView: UITextView!
    
    @IBOutlet weak var osmoImage: UIImageView!
    @IBOutlet weak var osmoStatus: UIImageView!
    @IBOutlet weak var gpsConnectionImage: UIImageView!
    @IBOutlet weak var playStopBtn: UIButton!

    @IBOutlet weak var pauseBtn: UIButton!
    @IBOutlet weak var slider: UIScrollView!
    @IBOutlet weak var link: UIButton!
    
    @IBOutlet weak var sliderImg: UIView!
    @IBOutlet weak var fronSliderImg: UIView!
    
    @IBOutlet weak var trackingModeBtn: UIButton!

    @IBAction func pauseClick(_ sender: AnyObject) {
        isSessionPaused = !isSessionPaused
        
        if isMonitoringOn {
            #if TARGET_OS_IOS
            Analytics.logEvent("trip_pause", parameters: nil)
            #endif
            
            sendingManger.pauseSendingCoordinates()
        } else {
            connectionManager.isGettingLocation = false
            sendingManger.startSendingCoordinates(false)
        }
    }
    
    @IBAction func GoByLink(_ sender: UIButton) {
        if let sessionUrl = connectionManager.sessionUrl, let url = sessionUrl.addingPercentEncoding (withAllowedCharacters: CharacterSet.urlQueryAllowed) {
            
            if let checkURL = URL(string: url) {
                let safariActivity = SafariActivity()
                let activityViewController = UIActivityViewController(activityItems: [checkURL], applicationActivities: [safariActivity])
                activityViewController.popoverPresentationController?.sourceView = sender
                self.present(activityViewController, animated: true, completion: {})
            }
        } else {
            log.enqueue("error: invalid url")
        }
    }
    
    @IBAction func MonitoringAction(_ sender: AnyObject) {
        if SettingsManager.getKey(SettingKeys.trackerId) as String? != ""{
            if isSessionPaused || isMonitoringOn {
                #if TARGET_OS_IOS
                Analytics.logEvent("trip_stop", parameters: nil)
                #endif
                
                sendingManger.stopSendingCoordinates()
                
                //UIApplication.shared.isIdleTimerDisabled = false
            } else {
                if (connectionManager.transports.count > 0) {
                    self.SelectPrivacy()
                }
                
            }
        }
    }

    func SelectTransportType() {
        let myAlert: UIAlertController = UIAlertController(title: title, message: NSLocalizedString("Transport type", comment: "Select type of transport"), preferredStyle: .alert)
        var idx:Int = 0
        
        while (idx < connectionManager.transports.count) {
            let transport = connectionManager.transports[idx];
            if (transport.name != "") {
                myAlert.addAction(UIAlertAction(title: transport.name, style: .default, handler: { (alert: UIAlertAction!) -> Void in
                    self.connectionManager.transportType = transport.id;
                    #if TARGET_OS_IOS
                    Analytics.logEvent("trip_start", parameters: nil)
                    #endif
                    
                    self.sendingManger.startSendingCoordinates(false)
                    
                    //UIApplication.shared.isIdleTimerDisabled = true
                }))
            }
            idx += 1;
        }
        self.present(myAlert, animated: true, completion: nil)
    }
    
    func SelectPrivacy() {
        func privacyName(_ privacy: Int) -> String {
            var name = ""
            switch privacy {
                case Privacy.everyone.rawValue:
                    name = NSLocalizedString("Everyone", comment: "Trip visible to everyone")
                case Privacy.shared.rawValue:
                    name = NSLocalizedString("Shared", comment: "Trip visible by link")
                case Privacy.me.rawValue:
                    name = NSLocalizedString("None", comment: "Trip visible to noone")
                default:
                    name = NSLocalizedString("Everyone", comment: "Trip visible to everyone")
            }
            return name
        }
        let myAlert: UIAlertController = UIAlertController(title: title, message: NSLocalizedString("Set visibility of trip", comment: "Set visibility of trip"), preferredStyle: .alert)
        var idx:Int = 0
        
        while (idx < Privacy.PRIVACY_COUNT.rawValue) {
            let name = privacyName(idx);
            if (name != "") {
                myAlert.addAction(UIAlertAction(title: name, style: .default, handler: { (alert: UIAlertAction!) -> Void in
                    self.connectionManager.trip_privacy = idx;
                    self.SelectTransportType()
                }))
            }
            idx += 1;
        }
        self.present(myAlert, animated: true, completion: nil)
    }
    
    func uiSettings(){
        //TODO: make for different iPhoneSizes
        //slider.contentSize = CGSize(width: 640, height: 458)
        slider.contentSize = CGSize(width: self.view.frame.width * 2, height: self.view.frame.height)
        MDView.text = SettingsManager.getKey(SettingKeys.motd) as String? ?? ""
        
        if let trackerId = SettingsManager.getKey(SettingKeys.trackerId) as String? {
            self.trackerID.setTitle("TrackerID:\(trackerId)", for: UIControl.State())
        }

        //UITabBar.appearance().tintColor = UIColor(red: 255/255, green: 102/255, blue: 0/255, alpha: 1.0)

        //sliderImg.roundCorners([.TopRight , .BottomRight], radius: 2)
        //fronSliderImg.roundCorners([.TopLeft , .BottomLeft], radius: 2)
    }
    
    fileprivate func updateSessionValues(_ elapsedTime: Int){
        let (h, m, s) = durationBySecond(seconds: elapsedTime)
        let strH: String = h > 9 ? "\(h):" : h == 0 ? "" : "0\(h):"
        let strM: String = m > 9 ? "\(m):" : "0\(m):"
        let strS: String = s > 9 ? "\(s)" : "0\(s)"
        
        if let timeLabel = self.timeLabel {
            timeLabel.text = "\(strH)\(strM)\(strS)"
            
        }
        let distance = sendingManger.locationTracker.distance;
        if let distanceLabel = self.distanceLabel {
            distanceLabel.text = String(format:"%.2f", distance)
        }
        
        let locs: [LocationModel] = sendingManger.locationTracker.lastLocations

        if let loc = locs.last {
            var speed = loc.speed * 3.6
            if speed < 0 {
                speed = 0
            }
            if let speedLabel = self.avgSpeedLabel {
                speedLabel.text = String(format:"%.0f", speed)
            }
        }

    }
    
    fileprivate func durationBySecond(seconds s:Int) -> (hours: Int, minutes: Int, seconds: Int){
        return ((s % (24*3600))/3600, s%3600/60, s%60)
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        _ = sendingManger.sentObservers.add(self, type(of: self).onSentCoordinate)
       
        sessionTimer = SessionTimer(handler: updateSessionValues)
        
        uiSettings()
        //setup handler for open connection
        _ = connectionManager.dataSendStart.add{
            DispatchQueue.main.async {
                self.osmoImage.image = UIImage(named:"small-blue")
            }
        }
        _ = connectionManager.dataSendEnd.add{
            DispatchQueue.main.async {
                self.osmoImage.image = UIImage(named:"small-green")
            }
        }
        _ = connectionManager.connectionStart.add{
            DispatchQueue.main.async {
                self.osmoImage.image = UIImage(named:"small-yellow")
            }
        }
        _ = connectionManager.connectionClose.add{
            DispatchQueue.main.async {
                self.osmoImage.image = UIImage(named:"small-red")
            }
        }
        _ = connectionManager.connectionRun.add{
            let theChange = ($0.0 == 0)
            
            if theChange {
                self.onMessageOfTheDayUpdated = self.connectionManager.messageOfTheDayReceived.add{
                    self.MDView.text = $1
                    if UIApplication.shared.applicationState != .active {
                        let app = UIApplication.shared.delegate as! AppDelegate
                        app.displayNotification("OsMo — Tracker", $1)
                    }
                }
                self.groupManager.groupList(true)
                self.connectionManager.activatePoolGroups(1) //Активируем получение обновления групп
            } else if let glUpdated = self.onGroupListUpdated {
                self.groupManager.groupListUpdated.remove(glUpdated)
            }
            DispatchQueue.main.async {
                if let user = SettingsManager.getKey(SettingKeys.user) {
                    if user.length > 0 {
                        self.userLabel.text = user as String
                    } else {
                        self.userLabel.text = ""
                    }
                } else {
                    self.userLabel.text = ""
                }
                
                if let trackerId = self.connectionManager.TrackerID{
                    self.trackerID.setTitle("TrackerID:\(trackerId)", for: UIControl.State())
                }
                self.osmoImage.image = theChange ? UIImage(named:"small-green")! : UIImage(named:"small-red")!
                
            }
            
            self.log.enqueue("MVC: The connection status was changed: \(theChange)")
            
            //self.osmoStatus.isHidden = !theChange
            
            if !theChange && !$0.1.isEmpty {
                self.alert(NSLocalizedString("Error", comment:"Error title for alert"), message: $0.1)
            }
        }
        
        _ = connectionManager.sessionRun.add{
            let theChange = ($0.0 == 0)
            
            self.isMonitoringOn = theChange
            
            
            if theChange {
                if let sUrl = self.connectionManager.sessionUrl {
                    self.link.setTitle(sUrl, for: UIControl.State())
                    self.link.isEnabled = true
                }
                
                self.log.enqueue("MVC: The session was opened")
                
                self.playStopBtn.setImage(UIImage(named: "stop-100"), for: UIControl.State())
                self.pauseBtn.isHidden = false
                
                if self.sessionTimer != nil && !self.sessionTimer!.IsStarted {
                    self.sessionTimer!.reset()
                }
            } else {
                
                self.link.setTitle($0.1.isEmpty ? NSLocalizedString("session was closed", comment:"session was closed") : $0.1, for: UIControl.State())
                self.link.isEnabled = false
                
                self.log.enqueue("MVC: The session was closed")
                
                self.pauseBtn.isHidden = true
                self.playStopBtn.setImage(UIImage(named: "play-100"), for: UIControl.State())
                self.isSessionPaused = false
                self.pauseBtn.setImage(UIImage(named: "pause-32"), for: UIControl.State())
                //if self.mainAnnotation != nil {self.mapView.removeAnnotation(self.mainAnnotation!)}
                //self.mainAnnotation = nil
                
                if let sessionTimer = self.sessionTimer {
                    sessionTimer.stop()
                }
            }
        }
        
        self.onSessionPaused = sendingManger.sessionPaused.add{
            if $0 == 0 {
                self.isMonitoringOn = false
                self.isSessionPaused = true
                self.pauseBtn.setImage(UIImage(named: "play-32"), for: UIControl.State())
                if let sessionTimer = self.sessionTimer {
                    sessionTimer.stop()
                }
            }
        }
        
        self.onSessionStarted = sendingManger.sessionStarted.add{
            if $0 == 0 {
                self.isMonitoringOn = true
                self.isSessionPaused = false
                self.pauseBtn.setImage(UIImage(named: "pause-32"), for: UIControl.State())
                if let sessionTimer = self.sessionTimer {
                    sessionTimer.start()
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // Dispose of any resources that can be recreated.
    }

    //handler for sent coordinate
    func onSentCoordinate(_ location: LocationModel){
        
        //moveToPosition(location)
        //drawLocationOnMap([location])
    }

    
    func alert(_ title: String, message: String) {
        let myAlert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        myAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(myAlert, animated: true, completion: nil)
    }

}



