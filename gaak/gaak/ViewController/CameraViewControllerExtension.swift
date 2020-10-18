//
//  CameraViewControllerExtension.swift
//  gaak
//
//  Created by Ted Kim on 2020/10/02.
//  Copyright © 2020 Ted Kim. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

extension CameraViewController {
    
    
    
    //MARK: 사진 촬영
    @IBAction func capturePhoto(_ sender: UIButton) {
        // TODO: photoOutput의 capturePhoto 메소드
        // orientation
        // photooutput
        
        let videoPreviewLayerOrientation = self.previewView.videoPreviewLayer.connection?.videoOrientation
        
        sessionQueue.async {
            let connection = self.photoOutput.connection(with: .video)
           
            connection?.videoOrientation = videoPreviewLayerOrientation!
            
            // 캡쳐 세션에 요청하는것
            let setting = AVCapturePhotoSettings()
            
            self.photoOutput.capturePhoto(with: setting, delegate: self)
        }
    }
    
    //MARK: 사진 저장
    func savePhotoLibrary(image: UIImage) {
        // TODO: capture한 이미지 포토라이브러리에 저장
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // save !
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { (_, error) in
                    self.setLatestPhoto()
                }
            } else {
                print(" error to save photo library")
                // 다시 요청할 수도 있음
                // ...
            }
        }
    }
    
    // MARK: - 라이브러리에 저장
    // 사진 저장할 때 화면비에 맞게 잘라서 저장해주는 함수
    /* 지금은 너무 코드가 더러움... 보기좋게 Constants를 만듥 것!! */
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // TODO: capturePhoto delegate method 구현
        guard error == nil else { return }
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard let image = UIImage(data: imageData) else { return }
        
        // 여기부터 // 더러워지기 시작 // 아랫부분 수정할 것
        var croppedImage: UIImage = image
        
        if( screenRatioSwitchedStatus == 0 ) { // 1:1 비율일 때
            
            let rectRatio = CGRect(x: 0, y: image.size.height - image.size.width, width: image.size.width, height: image.size.width)
                        
            croppedImage = cropImage2(image: image, rect: rectRatio, scale: 1.0) ?? image
        }
        else if( screenRatioSwitchedStatus == 1 ) {
            
            let rectRatio = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.width*4.0/3.0)
                        
            croppedImage = cropImage2(image: image, rect: rectRatio, scale: 1.0) ?? image
        }
        else {
            
            let rectRatio = CGRect(x: (image.size.width)/(4.0)/(2.0), y: 0, width: (image.size.height)*(9.0)/(16.0), height: image.size.height)
            
            croppedImage = cropImage2(image: image, rect: rectRatio, scale: 1.0) ?? image
        }
        // cripImage2 함수도 같이 정리할 것.
        self.savePhotoLibrary(image: croppedImage)
    }
    
    func cropImage2 (image : UIImage, rect : CGRect, scale : CGFloat)-> UIImage? {
        UIGraphicsBeginImageContextWithOptions (
            CGSize (width : rect.size.width / scale, height : rect.size.height / scale), true, 0.0)
        image.draw (at : CGPoint (x : -rect.origin.x / scale, y : -rect.origin.y / scale))
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext ()
        UIGraphicsEndImageContext ()
        return croppedImage
    }
    
    
    //MARK: 카메라 전후 전환 icon
    func updateSwitchCameraIcon(position: AVCaptureDevice.Position) {
        // TODO: Update ICON
        switch position {
        case .front:
            let image = #imageLiteral(resourceName: "ic_camera_front")
            switchButton.setImage(image, for: .normal)
        case .back:
            let image = #imageLiteral(resourceName: "ic_camera_rear")
            switchButton.setImage(image, for: .normal)
        default:
            break
        }
    }
    //MARK: 카메라 전후 전환 func
    @IBAction func switchCamera(sender: Any) {
        // TODO: 카메라는 2개 이상이어야함
        guard videoDeviceDiscoverySession.devices.count > 1 else { return }
        
        // TODO: 반대 카메라 찾아서 재설정
        // - 반대 카메라 찾고
        // - 새로운 디바이스를 가지고 세션을 업데이트
        // - 카메라 전환 토글 버튼 업데이트
        
        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            self.currentPosition = currentVideoDevice.position
            let isFront = self.currentPosition == .front
            // isFront이면 back에 있는걸, front가 아니면 front를 -> prefferedPosition
            let preferredPosition: AVCaptureDevice.Position = isFront ? .back : .front
            
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice?
            
            newVideoDevice = devices.first(where: { device in
                return preferredPosition == device.position
            })
            // -> 지금까지는 새로운 카메라를 찾음.
            
            // update capture session
            if let newDevice = newVideoDevice {
                
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: newDevice)
                    self.captureSession.beginConfiguration()
                    self.captureSession.removeInput(self.videoDeviceInput)
                    
                    // 새로 찾은 videoDeviceInput을 넣을 수 있으면 // 새로운 디바이스 인풋을 넣음
                    if self.captureSession.canAddInput(videoDeviceInput) {
                        self.captureSession.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else { // 아니면 그냥 원래 있던거 다시 넣고
                        self.captureSession.addInput(self.videoDeviceInput) // 이 조건문 다시보기
                    }
                    self.captureSession.commitConfiguration()
                    
                    // 카메라 전환 토글 버튼 업데이트
                    // UI관련 작업은 Main Queue에서 수행되어야 함
                    // 카메라 기능과 충돌이 생기면 안 되기 때문
                    DispatchQueue.main.async {
                        self.updateSwitchCameraIcon(position: preferredPosition)
                    }
                    
                } catch let error {
                    print("error occured while creating device input: \(error.localizedDescription)")
                }
            }
        }
    }
    
    
    //MARK: 더보기 func
    @IBAction func seeMore(_ sender: Any) {
        if(moreView.isHidden) {
            moreView.isHidden = false
            moreView.alpha = 1
        }
    }
    @IBAction func returnToMain(_ sender: Any) {
        // return to main View
        if (!moreView.isHidden) {
            moreView.isHidden = true
        }
    }
    
    //MARK: 화면비 변경 버튼
    /*
     이 함수에서 화면비 아이콘도 변경하고 previewView의 사이즈도 변경함.
     !!To do!!
        - preview 사이즈 변경할 때 지금은 previewConstraints.constant가
           지저분하게 작성되어있는데, 깔끔하게 정리할 필요가 있음.
     */
    @IBAction func switchScreenRatio(_ sender: Any) {
        // 0 == 1:1 || 1 == 3:4 || 2 == 9:16
        
        screenRatioSwitchedStatus += 1
        screenRatioSwitchedStatus %= ScreenType.numberOfRatioType()
        if let currentPosition = self.currentPosition {
            switch screenRatioSwitchedStatus {
            case ScreenType.Ratio.square.rawValue :
                screenRatioBarButtonItem.image = UIImage(named: "screen_ratio_1_1")

            case ScreenType.Ratio.retangle.rawValue :
                screenRatioBarButtonItem.image = UIImage(named: "screen_ratio_3_4")
            
            case ScreenType.Ratio.full.rawValue :
                screenRatioBarButtonItem.image = UIImage(named: "screen_ratio_9_16")

            default:
                break;
            }
            // 전후면 카메라 스위칭 될 때, 화면 비율을 넘기기 위함.
            // 이거 필요없으면 나중에 삭제하는게 좋음
            // extension으로 빼놨음.
            setToolbarsUI()
            getSizeByScreenRatio(with: currentPosition, at: screenRatioSwitchedStatus)
        }
    }
    
    // MARK: 앨범버튼 썸네일 설정
    // 에러있어서 현재 상수 입력해놓았음. imageManger 에서 targetsize 적어야하는데 지금은 그냥 44 로 적어놨음.
    // 버튼 객체에 접근해서 .frame.size으로 하면 UI API 가 백그라운드에서 수행중이라고 에러 뜸.
    func setLatestPhoto(){
        PHPhotoLibrary.authorizationStatus()
        
        authorizationStatus = PHPhotoLibrary.authorizationStatus()
        
        if let authorizationStatusOfPhoto = authorizationStatus {
            switch authorizationStatusOfPhoto {
            case .authorized:
                self.imageManger = PHCachingImageManager()
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                
                self.assetsFetchResults = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: options)
                
                //self.photoAlbumCollectionView?.reloadData()
           
            case .denied:
                print(authorizationStatusOfPhoto)
            case .notDetermined:
                print(authorizationStatusOfPhoto)
                PHPhotoLibrary.requestAuthorization({ (authorizationStatus) in
                    print(authorizationStatus.rawValue)
                })
            case .restricted:
                print(authorizationStatusOfPhoto)
            case .limited:
                print("접근제한(.limited): \(authorizationStatusOfPhoto)")
            @unknown default:
                print("@unknown error: \(authorizationStatusOfPhoto)")
            }
        }
        
        let asset: PHAsset = self.assetsFetchResults![0]
        self.imageManger?.requestImage(for: asset,
                                       targetSize: CGSize(width: 44, height: 44),
                                       contentMode: PHImageContentMode.aspectFill,
                                       options: nil,
                                       resultHandler: { (result : UIImage?, info) in
                                        DispatchQueue.main.async {
                                            self.photoLibraryButton.setImage(result, for: .normal)
                                        } } )
    }
    
    //MARK: 상, 하단 툴 바 설정
    func setToolbarsUI(){
        
        // 화면비에 따른 상, 하단 툴바 상태 조절
        switch screenRatioSwitchedStatus {
        case ScreenType.Ratio.square.rawValue :
            print("-> UI setup: screen_ratio 1_1")
            
            // setToolbarsUI // tool bar UI 설정하는 부분
            settingToolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
            settingToolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
            settingToolbar.isTranslucent = false
            cameraToolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
            cameraToolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
            cameraToolbar.isTranslucent = false
            
            cameraToolBarHeight.constant = view.frame.size.height - (view.frame.size.width + settingToolbar.frame.size.height)
        
        case ScreenType.Ratio.retangle.rawValue :
            print("-> UI setup: screen_ratio 3_4")
            
            settingToolbar.isTranslucent = true
            cameraToolbar.isTranslucent = false
            
            cameraToolBarHeight.constant = view.frame.size.height - ((view.frame.size.width)*(4.0/3.0))
            
        case ScreenType.Ratio.full.rawValue :
            print("-> UI setup: screen_ratio 9:16")

            settingToolbar.isTranslucent = true
            cameraToolbar.isTranslucent = true
            
            cameraToolBarHeight.constant = view.frame.size.height - ((view.frame.size.width)*(4.0/3.0))


        default:
            print("--> screenRatioSwitchedStatus: default")
        }
    }
    
}
