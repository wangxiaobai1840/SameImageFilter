//
//  ViewController.swift
//  ImageFind
//
//  Created by wanglixia05 on 2021/7/5.
// 对文件夹下的相同图片进行筛选

import Cocoa
import CommonCrypto

class ViewController: NSViewController {
    let fileSelectedText: NSText = NSText()
    var imageDic: Dictionary = [String: [String]]()
    var selectedURL: URL!
    var saveURL: URL!
    let savePathText: NSText = NSText()
    var ignoreText: NSTextField = NSTextField()
    var ignoreArray: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        createUI()

    }
    func createUI(){
        let button = NSButton(title: "选择文件", image: NSImage(), target: self, action: #selector(selectedFile))
        button.frame = NSRect(x: 10, y: self.view.frame.size.height - 30, width: 150, height: 30)
        self.view.addSubview(button)

        fileSelectedText.frame = NSRect(x: button.frame.origin.x + button.frame.size.width + 10, y: self.view.frame.size.height - 20, width: self.view.frame.size.width - button.frame.size.width - 20, height: 30)
        fileSelectedText.isEditable = false
        self.view.addSubview(fileSelectedText)

        let saveButton = NSButton(title: "保存路径", image: NSImage(), target: self, action: #selector(selectedSavePath))
        saveButton.frame = NSRect(x: 10, y:  button.frame.origin.y - button.frame.size.height - 10, width: 150, height: 30)
        self.view.addSubview(saveButton)

        savePathText.frame = NSRect(x: button.frame.origin.x + button.frame.size.width + 10, y:  saveButton.frame.origin.y + 10, width: self.view.frame.size.width - button.frame.size.width - 20, height: 30)
        savePathText.isEditable = false
        self.view.addSubview(savePathText)
        ignoreText.frame = CGRect(x: saveButton.frame.origin.x, y: saveButton.frame.origin.y - saveButton.frame.size.height - 10, width: self.view.frame.size.width - 20, height: 30)
        ignoreText.placeholderString = "需要忽略的文件夹，多个以 , 隔开"
        self.view.addSubview(ignoreText)

        let tips = NSText()
        tips.textColor = .red
        tips.backgroundColor = .clear
        tips.frame = CGRect(x: button.frame.origin.x, y: ignoreText.frame.origin.y - ignoreText.frame.size.height + 10, width: ignoreText.frame.size.width, height: 30)
        tips.string = "自动忽略对Pods文件夹下图片的筛选"
        self.view.addSubview(tips)

        let submitButton = NSButton(title: "确认筛选", target: self, action: #selector(submitButtonClickAction))
        submitButton.frame = CGRect(x: button.frame.origin.x, y: tips.frame.origin.y - tips.frame.size.height - 20, width: 150, height: 30)
        self.view.addSubview(submitButton)
    }

    @objc func selectedFile(){
        guard let url = selectedPath() else {
            return
        }
        selectedURL = url
        fileSelectedText.string = selectedURL.relativePath
    }

    @objc func selectedSavePath(){
        guard let url = selectedPath() else {
            return
        }
        saveURL = url
        savePathText.string = saveURL.relativePath
    }

    func selectedPath()->URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        let find = panel.runModal()
        if find == .OK {
            print(panel.urls)
            return panel.url
        }
        return nil
    }

    @objc func submitButtonClickAction(){
        if saveURL == nil || selectedURL == nil {
            let alert = NSAlert()
            alert.messageText = "请选择正确的\(selectedURL == nil ? "文件" : "保存")路径"
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        imageDic.removeAll()
        ignoreArray.removeAll()
        if ignoreText.stringValue.count > 0 {
            ignoreArray = ignoreText.stringValue.components(separatedBy: ",")
        }
        let fileArray: [String] = FileManager.default.subpaths(atPath: selectedURL.relativePath) ?? []
        if fileArray.count <= 0 {
            return
        }
        for subPath in fileArray {
            if let url = URL(string: selectedURL.relativePath + "/" + subPath) {
                dfs(path: url)
            }
        }
        var dic:[String:[String]] = [String: [String]]()
        for key in imageDic.keys {
            let array = imageDic[key]
            if array?.count ?? 0 > 1 {
                dic[key] = array
            }
        }
        let jsonString = jsonToString(jsonDic: dic)
        try? jsonString?.write(toFile: saveURL.relativePath + "/filter.txt", atomically: true, encoding: .utf8)
        let alert = NSAlert()
        alert.messageText = "已筛选完成"
        alert.alertStyle = .informational
        alert.runModal()
    }

    // MARK: dictionary to data
    func jsonToString(jsonDic:Dictionary<String, Any>) -> String? {
        if (!JSONSerialization.isValidJSONObject(jsonDic)) {
            print("is not a valid json object")
            return nil
        }
        guard let data = try? JSONSerialization.data(withJSONObject: jsonDic, options: []) else { return "" }
        let string = String(data: data, encoding: .utf8)
        return string
    }
    // MARK: 进行对图片文件筛选并转换md5
    func dfs(path: URL){
        let fileManger = FileManager.default
        var isDir: ObjCBool = ObjCBool(false)
        if path.relativePath.contains("/Pods/") || path.relativePath.contains("/SAKShare/"){
            return
        }
        if ignoreArray.count > 0 {
            for item in ignoreArray {
                if path.relativePath.contains("/\(item)/") {
                    return
                }
            }
        }
        let isExist = fileManger.fileExists(atPath: path.relativePath, isDirectory: &isDir)
        if !isExist {
            return
        }
        if isDir.boolValue == false {
            if path.relativePath.hasSuffix(".png") || path.relativePath.hasSuffix(".PNG") {
                let image = NSImage(contentsOfFile: path.relativePath)
                if let data = image?.tiffRepresentation {
                    let key = get(data: data)
                    var imageArray: [String] = self.imageDic[key] ?? []
                    imageArray.append(path.relativePath)
                    self.imageDic[key] = imageArray
                    return
                }
            }
            return
        }
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
// MARK: data转md5
    func get(data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            CC_MD5(bytes, CC_LONG(data.count), &digest)
        }
        var digestHex = ""
        for index in 0..<Int(CC_MD5_DIGEST_LENGTH) {
            digestHex += String(format: "%02x", digest[index])
        }
        return digestHex
    }
}
