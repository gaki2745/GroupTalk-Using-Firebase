//
//  SignInViewController.swift
//  GroupTalk
//
//  Created by youngjun goo on 27/01/2019.
//  Copyright © 2019 youngjun goo. All rights reserved.
//

import UIKit
import Firebase

class SignUpViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var pwdTextField: UITextField!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var cancelButton: RoundedWhiteButton!
    @IBOutlet weak var continueButton: RoundedWhiteButton!
    
    var activityView: UIActivityIndicatorView!
    
    @IBAction func signUpAction(_ sender: Any) {
        doSignUp()
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    let remoteConfig = RemoteConfig.remoteConfig()
    var colorString: String! = nil
    var ref: DatabaseReference!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addVerticalGradientLayer(topColor: primaryColor, bottomColor: secondaryColor)
        self.ref = Database.database().reference()
        
        tapProfileImage()
        setUpLayout()
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    fileprivate func setUpLayout() {
        let statusBar = UIView()
        self.view.addSubview(statusBar)
        statusBar.snp.makeConstraints{ (m) in
            m.right.top.left.equalTo(self.view)
            m.height.equalTo(20)
        }
        colorString = remoteConfig["splash_background"].stringValue
        statusBar.backgroundColor = UIColor(hex: colorString)
        // signUpButton.backgroundColor = UIColor(hex: colorString)
    }
    
}

extension SignUpViewController {
    
    func showAlert(message: String) {
        
        let alert = UIAlertController(title: "회원가입 실패", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        self.present(alert, animated: true, completion: nil)
    }
    
    func doSignUp() {
        
        if emailTextField.text! == "" {
            showAlert(message: "이메일을 입력해주세요.")
            return
        }
        
        if pwdTextField.text! == "" {
            showAlert(message: "비밀 번호를 입력해 주세요.")
            return
        }
        
        if nameTextField.text! == "" {
            showAlert(message: "이름을 입력해 주세요.")
            return
        }
        
        signUp(email: emailTextField.text!, password: pwdTextField.text!, name: nameTextField.text!)
    }
    
    func setContinueButton(enable: Bool) {
        if enable {
            continueButton.alpha = 1.0
            continueButton.isEnabled = true
        } else {
            continueButton.alpha = 0.5
            continueButton.isEnabled = false
        }
    }
    
    func signUp(email: String, password: String, name: String) {
        
        setContinueButton(enable: false)
        continueButton.setTitle("", for: .normal)
        //activityView.startAnimating()
        
        Auth.auth().createUser(withEmail: email, password: password) { user, error in
            if error == nil && user != nil {
                print("Urser Created")
                
                self.uploadProfileImage(self.profileImageView.image!) { url in
                    
                    if url != nil {
                        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
                        changeRequest?.displayName = name
                        changeRequest?.photoURL = url
                        
                        changeRequest?.commitChanges { error in
                            if error == nil {
                                print("유저이름 변경")
                                self.saveProfileImage(userName: name, profileImageURL: url!) { success in
                                    if success {
                                        print("회원가입 성공")
                                        self.dismiss(animated: true, completion: nil)
                                    } else {
                                        self.showAlert(message: "회원 가입 실패1")
                                    }
                                }
                                
                            } else {
                                print("Error: \(error!.localizedDescription)")
                                self.showAlert(message: "회원 가입 실패2")
                            }
                        }
                    } else {
                        self.showAlert(message: "회원 가입 실패3")
                    }
                }
            } else {
                self.showAlert(message: "회원 가입 실패4")
            }
        }
        
    }
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let changedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
            self.profileImageView.image = changedImage //편집된 사진을 뷰에 present
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    func uploadProfileImage(_ image: UIImage, completion: @escaping ((_ url: URL?) -> ())) {
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let storageRef = Storage.storage().reference().child("user/\(uid)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.75) else { return }
        
        let metaData = StorageMetadata()
        metaData.contentType = "image/jpg"
        
        storageRef.putData(imageData, metadata: metaData) { metaData, error in
            if error == nil, metaData != nil {
                storageRef.downloadURL { url, error in
                    if error != nil {
                        completion(nil)
                    } else {
                        completion(url)
                    }
                }
            } else {
                completion(nil)
            }
        }
    }
    
    func tapProfileImage() {
        
        var tapGesture = UITapGestureRecognizer()
        
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.profileImagePicker))
        tapGesture.numberOfTapsRequired = 1 //한번 탭 에 열림
        self.profileImageView.addGestureRecognizer(tapGesture)
        self.profileImageView.isUserInteractionEnabled = true
        
    }
    
    @objc func profileImagePicker() {
        
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        //선택한 사진을 수정 할 수 있는 여부를 정하는 값
        imagePicker.allowsEditing = true
        imagePicker.sourceType = .photoLibrary
        
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    
    func saveProfileImage(userName: String, profileImageURL: URL, completion: @escaping ((_ success: Bool)->())) {
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let databaseRef = Database.database().reference().child("users/profile/\(uid)")
        
        let userObject = ["userName": userName, "photoURL": profileImageURL.absoluteString] as [String: Any]
        
        databaseRef.setValue(userObject) { error, ref in
            completion(error == nil)
        }
    }
    
    
    
}
