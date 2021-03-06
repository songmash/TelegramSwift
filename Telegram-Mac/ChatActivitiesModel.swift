//
//  ChatActivitiesModel.swift
//  TelegramMac
//
//  Created by keepcoder on 23/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

enum ChatActivityAnimation {
    case none
    case text
    case uploading
    case recording
}



class ChatActivitiesView : View {
    
    
    private let textView:TextView = TextView()
    private let animationView:ImageView = ImageView(frame: NSMakeRect(0,-4,30,20))
    private var isAnimating:Bool = false
    
    private var type:ChatActivityAnimation?
    private var theme:ActivitiesTheme?
    
    override init() {
        super.init()
        addSubview(textView)
        addSubview(animationView)
    }
    
    override func layout() {
        super.layout()
        
    }
    
    func updateBackground(_ background:NSColor) {
        self.backgroundColor = background
        self.textView.backgroundColor = background
        needsDisplay = true
    }
    
    func layout(with params:(ChatActivityAnimation, TextViewLayout?), width:CGFloat, theme:ActivitiesTheme) -> Void {
        
        textView.userInteractionEnabled = false
        if params.0 == .none {
            stopAnimation()
        } else {
            startAnimation(params.0, theme:theme)
        }
        
        if let layout = params.1 {
            setFrameSize(layout.layoutSize.width + animationView.frame.width, layout.layoutSize.height)
        }
        textView.update(params.1, origin:NSMakePoint(animationView.frame.width , 0))
    }
    
    func startAnimation(_ type:ChatActivityAnimation, theme:ActivitiesTheme) {
        self.type = type
        self.theme = theme
        isAnimating = true
        let animation = CAKeyframeAnimation(keyPath: "contents")
        switch type {
        case .recording:
            animation.values = theme.recording
            animation.duration = 0.7
        case .uploading:
            animation.values = theme.uploading
            animation.duration = 1.75
        default:
            animation.values = theme.text
            animation.duration = 0.7
        }
        animation.repeatCount = .greatestFiniteMagnitude
        animationView.layer?.add(animation, forKey: "contents")
        
    }
    
    override func viewDidMoveToWindow() {
        if window == nil {
            self.stopAnimation(false)
        } else {
            if isAnimating, let type = type, let theme = theme {
                startAnimation(type, theme: theme)
            }
        }
    }
    
    func stopAnimation(_ realyStop:Bool = true) {
        if realyStop {
            isAnimating = false
        }
        animationView.layer?.removeAllAnimations()
        animationView.image = nil
        animationView.sizeToFit()
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}




class ChatActivitiesModel: Node {

    private(set) var isActive:Bool = false
    private let activityView:ChatActivitiesView
    private let disposable:MetaDisposable = MetaDisposable()
    
    func update(with activities:(PeerId, [(Peer, PeerInputActivity)]), for width:CGFloat, theme:ActivitiesTheme, layout:@escaping(Bool)->Void) {
        isActive = !activities.1.isEmpty
        activityView.updateBackground(theme.backgroundColor)
        disposable.set(renderedActivities(activities, for: width, theme:theme).start(next: { [weak self] data in
            self?.activityView.layout(with: data, width: width, theme: theme)
            layout(data.1 != nil)
        }))
    }
    
    private func renderedActivities(_ activities:(PeerId, [(Peer, PeerInputActivity)]), for width:CGFloat, theme: ActivitiesTheme) -> Signal <(ChatActivityAnimation, TextViewLayout?), Void> {
        return Signal { subscriber in
            

            
            if !activities.1.isEmpty {
                let layout:TextViewLayout
                var animation:ChatActivityAnimation = .text
                let text = NSMutableAttributedString()
                var sameActivity:Bool = true
                let isFew:Bool = activities.1.count > 1
                for (_, activity) in activities.1 {
                    if activity != activities.1[0].1 {
                        sameActivity = false
                        break
                    }
                    if case .typingText = activity {
                        sameActivity = false
                        break
                    }
                }
                
                if isFew {
                    if sameActivity {
                        let activity = activities.1[0].1
                        switch activity {
                            case .recordingVoice:
                                animation = .recording
                            _ = text.append(string: tr(.peerActivityChatMultiRecordingAudio(activities.1.count)), color: theme.textColor, font: .normal(.text))
                        case .uploadingFile:
                             animation = .uploading
                            _ = text.append(string: tr(.peerActivityChatMultiSendingFile(activities.1.count)), color: theme.textColor, font: .normal(.text))
                        case .uploadingPhoto:
                            animation = .uploading
                            _ = text.append(string: tr(.peerActivityChatMultiSendingPhoto(activities.1.count)), color: theme.textColor, font: .normal(.text))
                        case .uploadingVideo:
                            animation = .uploading
                            _ = text.append(string: tr(.peerActivityChatMultiSendingVideo(activities.1.count)), color: theme.textColor, font: .normal(.text))
                        //case .playingGame:
                            
                            //_ = text.append(string: tr(.peerActivityChatMultiPlayingGame(activities.1.count)), color: theme.textColor, font: .normal(.text))
                        case .recordingInstantVideo:
                            animation = .recording
                            _ = text.append(string: tr(.peerActivityChatMultiRecordingVideo(activities.1.count)), color: theme.textColor, font: .normal(.text))
                        default:
                            animation = .text
                            break
                        }
                    } else {
                        animation = .text
                        if activities.1.count > 2 {
                            _ = text.append(string: tr(.peerActivityChatMultiTypingText(activities.1.count)), color: theme.textColor, font: .normal(.text))
                        } else {
                            let names = activities.1.map({$0.0.compactDisplayTitle}).joined(separator: ", ")
                            _ = text.append(string: names, color: theme.textColor, font: .normal(.text))
                        }
                    }
                } else {
                    let activity = activities.1[0].1
                    let peer = activities.1[0].0
                    switch activity {
                    case .recordingVoice:
                        animation = .recording
                        if activities.0.namespace == Namespaces.Peer.CloudUser || activities.0.namespace == Namespaces.Peer.SecretChat {
                            _ = text.append(string: tr(.peerActivityUserRecordingAudio), color: theme.textColor, font: .normal(.text))
                        } else {
                            _ = text.append(string: peer.compactDisplayTitle, color: theme.textColor, font: .normal(.text))
                        }
                    case .uploadingFile:
                        animation = .uploading
                        if activities.0.namespace == Namespaces.Peer.CloudUser || activities.0.namespace == Namespaces.Peer.SecretChat {
                            
                            _ = text.append(string:tr(.peerActivityUserSendingFile), color: theme.textColor, font: .normal(.text))
                        } else {
                            _ = text.append(string: peer.compactDisplayTitle, color: theme.textColor, font: .normal(.text))
                        }
                    case .uploadingVideo:
                        animation = .uploading
                        if activities.0.namespace == Namespaces.Peer.CloudUser || activities.0.namespace == Namespaces.Peer.SecretChat {
                            
                            _ = text.append(string:tr(.peerActivityUserSendingVideo), color: theme.textColor, font: .normal(.text))
                        } else {
                            _ = text.append(string: peer.compactDisplayTitle, color: theme.textColor, font: .normal(.text))
                        }
                    case .uploadingPhoto:
                        animation = .uploading
                        if activities.0.namespace == Namespaces.Peer.CloudUser || activities.0.namespace == Namespaces.Peer.SecretChat {
                            
                            _ = text.append(string:tr(.peerActivityUserSendingPhoto), color: theme.textColor, font: .normal(.text))
                        } else {
                            _ = text.append(string: peer.compactDisplayTitle, color: theme.textColor, font: .normal(.text))
                        }
                    case .recordingInstantVideo:
                        animation = .recording
                        if activities.0.namespace == Namespaces.Peer.CloudUser || activities.0.namespace == Namespaces.Peer.SecretChat {
                            _ = text.append(string: tr(.peerActivityUserRecordingVideo), color: theme.textColor, font: .normal(.text))
                        } else {
                            _ = text.append(string: peer.compactDisplayTitle, color: theme.textColor, font: .normal(.text))
                        }
                    default:
                        animation = .text
                        if activities.0.namespace == Namespaces.Peer.CloudUser || activities.0.namespace == Namespaces.Peer.SecretChat {
                            _ = text.append(string: tr(.peerActivityUserTypingText), color: theme.textColor, font: .normal(.text))
                        } else {
                            _ = text.append(string: peer.compactDisplayTitle, color: theme.textColor, font: .normal(.text))
                        }
                    }
                }
                
                layout = TextViewLayout(text, maximumNumberOfLines: 1)
                layout.measure(width: width - 30)
                subscriber.putNext((animation, layout))
                subscriber.putCompletion()
            } else {
                subscriber.putNext((.none, nil))
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        } |> deliverOnMainQueue
    }
    
    deinit {
        disposable.dispose()
    }
    
    func clean() {
        disposable.set(nil)
        activityView.stopAnimation()
    }
    
    init() {
        self.activityView = ChatActivitiesView()
        super.init(activityView)
        
    }
    
}
