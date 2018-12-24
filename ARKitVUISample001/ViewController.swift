import ARKit
import AVFoundation
import SceneKit
import UIKit

// Sample Words:
// "青いターゲットを回転"
// "赤いターゲットを下に移動"
// "緑のターゲットを拡大"
// "Slackにテスト送信"

enum VUICommand {
    case noMatch
    case objectRotate
    case objectMove
    case objectScaleUp
    case objectScaleDown
    case sendToSlack
}

struct MoveParameter {
    var isUp: Bool

    var moveAmount: CGFloat {
        return isUp ? 0.08 : -0.08
    }
}

class ViewController: UIViewController {

    @IBOutlet private weak var sceneView: ARSCNView!

    @IBOutlet weak var resultLabel: UILabel!

    @IBOutlet private weak var recordButton: UIButton! {
        didSet {
            recordButton.layer.cornerRadius = 10
        }
    }

    @IBAction private func runButton_action(_ sender: Any) {
        if !isRecording {
            recordButton.setTitle("Stop", for: .normal)
            recordButton.backgroundColor = UIColor.red
            AudioRESTController.shared.record()
        } else {
            recordButton.setTitle("Run Voice Recognition", for: .normal)
            recordButton.backgroundColor = UIColor.clear
            AudioRESTController.shared.stop()
            AudioRESTController.shared.soundFileToText()
        }
        isRecording = !isRecording
    }

    private var sphereNodes: [SCNNode] = []
    private var isRecording = false

    override func viewDidLoad() {
        super.viewDidLoad()

        AudioRESTController.shared.prepare(delegate: self)

        sceneView.scene = SCNScene()
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.debugOptions = .showWireframe

        addSphere(position: SCNVector3Make(0, 0, -0.3), color: .red)
        addSphere(position: SCNVector3Make(0.1, 0, -0.3), color: .green)
        addSphere(position: SCNVector3Make(0.2, 0, -0.3), color: .blue)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    private func addSphere(position: SCNVector3, color: UIColor) {
        let s = SCNSphere(radius: 0.03)
        s.firstMaterial?.diffuse.contents = color
        s.segmentCount = 16
        let node = SCNNode(geometry: s)
        node.position = position
        sceneView.scene.rootNode.addChildNode(node)

        sphereNodes.append(node)
    }
}

extension ViewController: ARSCNViewDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
}

extension ViewController: AudioRESTControllerDelegate {
    func doneAnalyze(_ items: [String]) -> Void {
        print(items)
        guard let str = items.first else {
            resultLabel.text = "音声認識できませんでした"
            return
        }
        resultLabel.text = str
        processCommand(str: str)
    }
}

extension ViewController {
    private func findCommand(str: String) -> VUICommand {
        if str.contains("回転") {
            return .objectRotate
        } else if str.contains("移動") {
            return .objectMove
        } else if str.contains("拡大") {
            return .objectScaleUp
        } else if str.contains("縮小") {
            return .objectScaleDown
        } else if str.lowercased().contains("slack") {
            return .sendToSlack
        }
        return .noMatch
    }

    private func findTarget(str: String) -> SCNNode? {
        if str.contains("赤") {
            return sphereNodes[0]
        } else if str.contains("緑") {
            return sphereNodes[1]
        } else if str.contains("青") {
            return sphereNodes[2]
        }
        return nil
    }

    private func findMoveParameter(str: String) -> MoveParameter {
        if str.contains("下") {
            return MoveParameter(isUp: false)
        }
        return MoveParameter(isUp: true)
    }

    private func processCommand(str: String) {
        let command = findCommand(str: str)
        let target = findTarget(str: str)

        switch command {
        case .objectRotate:
            target?.runAction(SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 3))
        case .objectMove:
            let parameter = findMoveParameter(str: str)
            target?.runAction(SCNAction.moveBy(x: 0, y: parameter.moveAmount, z: 0, duration: 0.3))
        case .objectScaleUp:
            target?.runAction(SCNAction.scale(by: 2.0, duration: 0.3))
        case .objectScaleDown:
            target?.runAction(SCNAction.scale(by: 0.5, duration: 0.3))
        case .sendToSlack:
            sendToSlack(str)
        case .noMatch:
            break
        }
    }
}

extension ViewController {
    private func sendToSlack(_ sourceStr: String) {
        let service = "https://hooks.slack.com/services/[Web hook target URL]"
        let requestDictionary: [String: Any] = [
            "channel": "#bots",
            "username": "webhookbot",
            "text": "ARKit VUI Demo: \(sourceStr)"]
        let requestData = try! JSONSerialization.data(withJSONObject: requestDictionary, options: [])
        let request = NSMutableURLRequest(url: URL(string: service)!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        request.httpMethod = "POST"
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { (data, resp, err) in
            if let data = data {
                print(data)
            }
        })
        task.resume()
    }
}
