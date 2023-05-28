//
//  File.swift
//  
//
//  Created by Irham Naufal on 28/05/23.
//

import Foundation
import Combine
import SwiftUI
import StoreKit

final class ProfileViewModel: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {

    private let getUserUseCase: GetUserUseCase
    private let deleteUserUseCase: DeleteAccountUseCase
    private let coinVerificationUseCase: CoinVerificationUseCase

    var backToRoot: () -> Void
    var backToHome: () -> Void

    @Published var urlLinked = Configuration.shared.environment.usernameURL
    @Published var isPresentDeleteModal = false

    private var cancellables = Set<AnyCancellable>()

    private var stateObservable = StateObservable.shared

    @Published var route: HomeRouting?
    @Published var data: UserResponse?

    @Published var isLoading: Bool = false
    @Published var isError: Bool = false
    @Published var error: String?
    @Published var success: Bool = false

    @Published var showCopied = false

    @Published var userPhotos: String?
    @Published var names: String?
    @Published var userCoin: String?

    @Published var isRefreshFailed = false

    @Published var logoutPresented = false

    @Published var profesionSelect = [ProfessionData]()
    @Published var successDelete = false

    @Published var myProducts = [SKProduct]()

    @Published var productIDs = [
        "dinotisapp.coin01",
        "dinotisapp.coin02",
        "dinotisapp.coin03",
        "dinotisapp.coin04",
        "dinotisapp.coin05",
        "dinotisapp.coin06",
        "dinotisapp.coin07",
        "dinotisapp.coin08"
    ]

    var request: SKProductsRequest?

    @Published var transactionState: SKPaymentTransactionState?
    @Published var showAddCoin = false
    @Published var productSelected: SKProduct? = nil
    @Published var isTransactionSucceed = false
    @Published var isLoadingTrx = false

    @Published var statusCode = 0

    init(
        backToRoot: @escaping (() -> Void),
        backToHome: @escaping (() -> Void),
        getUserUseCase: GetUserUseCase = GetUserDefaultUseCase(),
        deleteUserUseCase: DeleteAccountUseCase = DeleteAccountDefaultUseCase(),
        coinVerificationUseCase: CoinVerificationUseCase = CoinVerificationDefaultUseCase()
    ) {
        self.backToHome = backToHome
        self.backToRoot = backToRoot
        self.getUserUseCase = getUserUseCase
        self.deleteUserUseCase = deleteUserUseCase
        self.coinVerificationUseCase = coinVerificationUseCase
    }

    func toggleDeleteModal() {
        self.isPresentDeleteModal.toggle()
    }

    func onStartedFetch() {
        DispatchQueue.main.async {[weak self] in
            self?.isError = false
            self?.isLoading = true
            self?.error = nil
            self?.success = false
            self?.successDelete = false
        }
    }

    func copyURL() {
        UIPasteboard.general.string = userLink()

        withAnimation {
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                withAnimation {
                    self?.showCopied = false
                }
            }
        }
    }

    func presentLogout() {
        self.logoutPresented.toggle()
    }

    func userLink() -> String {
        urlLinked + (data?.username).orEmpty()
    }

    func nameOfUser() -> String {
        (self.data?.name).orEmpty()
    }

    func isUserVerified() -> Bool {
        (self.data?.isVerified) ?? false
    }

    func userPhoto() -> String {
        (self.data?.profilePhoto).orEmpty()
    }
    
    func userProfession() -> [ProfessionData] {
        (self.data?.professions) ?? []
    }

    func userBio() -> String {
        (self.data?.profileDescription).orEmpty()
    }

    func openWhatsApp() {
        if let waurl = URL(string: "https://wa.me/6281318506068") {
            if UIApplication.shared.canOpenURL(waurl) {
                UIApplication.shared.open(waurl, options: [:], completionHandler: nil)
            }
        }
    }

    func routeToChangePass() {
        let viewModel = ChangesPasswordViewModel(backToRoot: self.backToRoot)

        DispatchQueue.main.async { [weak self] in
            self?.route = .changePassword(viewModel: viewModel)
        }
    }

    func routeToPreviewProfile() {
        let viewModel = PreviewTalentViewModel(backToRoot: self.backToRoot)

        DispatchQueue.main.async { [weak self] in
            self?.route = .previewTalent(viewModel: viewModel)
        }
    }
    
    func handleDefaultError(error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false

            if let error = error as? ErrorResponse {

                if error.statusCode.orZero() == 401 {
                    self?.error = error.message.orEmpty()
                    self?.isRefreshFailed.toggle()
                } else {
                    self?.error = error.message.orEmpty()
                    self?.isError = true
                }
            } else {
                self?.isError = true
                self?.error = error.localizedDescription
            }

        }
    }

    func getUsers() async {
        onStartedFetch()
        
        let result = await getUserUseCase.execute()
        
        switch result {
        case .success(let success):
            DispatchQueue.main.async { [weak self] in
                self?.success = true
                self?.isLoading = false
                
                self?.data = success
                self?.userPhotos = success.profilePhoto
                self?.names = success.name
                self?.userCoin = (success.coinBalance?.current).orEmpty().toPriceFormat()
            }
        case .failure(let failure):
            handleDefaultError(error: failure)
        }
    }

    func deleteAccount() async {
        onStartedFetch()
        
        let result = await deleteUserUseCase.execute()
        
        switch result {
        case .success(_):
            DispatchQueue.main.async { [weak self] in
                self?.success = true
                self?.isLoading = false
                self?.successDelete.toggle()
            }
        case .failure(let failure):
            handleDefaultError(error: failure)
        }
    }

    func routeBackLogout() {
        backToRoot()
        stateObservable.userType = 0
        stateObservable.isVerified = ""
        stateObservable.refreshToken = ""
        stateObservable.accessToken = ""
        stateObservable.isAnnounceShow = false
        OneSignal.setExternalUserId("")
    }

    func onStartRefresh() {
        self.isRefreshFailed = false
        self.isLoading = true
        self.success = false
        self.error = nil
    }

    func routeToEditProfile() {

        let viewModel = EditProfileViewModel(backToRoot: self.backToRoot, backToHome: self.stateObservable.userType == 2 ? self.backToHome : {self.route = nil})

        DispatchQueue.main.async { [weak self] in
            if self?.stateObservable.userType == 2 {
                self?.route = .editTalentProfile(viewModel: viewModel)
            } else {
                self?.route = .editUserProfile(viewModel: viewModel)
            }
        }
    }

    func routeToWallet() {
        let viewModel = TalentWalletViewModel(backToRoot: self.backToRoot, backToHome: self.backToHome)

        DispatchQueue.main.async { [weak self] in
            self?.route = .talentWallet(viewModel: viewModel)
        }
    }

    func verifyCoin(receipt: String, queue: SKPaymentQueue, transaction: SKPaymentTransaction) async {

        let result = await coinVerificationUseCase.execute(with: receipt)

        switch result {
        case .success(_):
            DispatchQueue.main.async {[weak self] in
                self?.showAddCoin = false
                self?.isLoadingTrx = false
                self?.isError = false
                self?.error = nil

                queue.finishTransaction(transaction)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.isTransactionSucceed.toggle()
                }

                self?.productSelected = nil
            }
            
            await self.getUsers()
        case .failure(let failure):
            handleDefaultErrorCoinVerify(error: failure)
        }

    }

    func handleDefaultErrorCoinVerify(error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoadingTrx = false
            self?.productSelected = nil

            if let error = error as? ErrorResponse {
                self?.error = error.message.orEmpty()


                if error.statusCode.orZero() == 401 {
                    self?.isRefreshFailed.toggle()
                } else {
                    self?.isError = true
                }
            } else {
                self?.isError = true
                self?.error = error.localizedDescription
            }

        }
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                DispatchQueue.main.async {[weak self] in
                    self?.isLoadingTrx = true
                    self?.isError = false
                    self?.error = nil
                }
                transactionState = .purchasing
            case .purchased:

                transactionState = .purchased

                if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
                   FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {

                    Task {
                        do {
                            let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
                            print(receiptData)

                            let receiptString = receiptData.base64EncodedString(options: [])

                            await self.verifyCoin(receipt: receiptString, queue: queue, transaction: transaction)
                        }
                        catch {
                            DispatchQueue.main.async {[weak self] in
                                self?.isLoadingTrx = false
                                self?.isError.toggle()
                                self?.error = error.localizedDescription
                            }
                        }
                    }
                }
            case .restored:
                DispatchQueue.main.async {[weak self] in
                    self?.isLoadingTrx = false
                    self?.isError = false
                    self?.error = nil
                }
                transactionState = .restored
                queue.finishTransaction(transaction)
                isTransactionSucceed.toggle()
                showAddCoin = false
                productSelected = nil
            case .failed, .deferred:
                transactionState = .failed
                DispatchQueue.main.async {[weak self] in
                    self?.isLoadingTrx = false
                    self?.isError.toggle()
                    self?.error = LocaleText.inAppsPurchaseTrx
                }
            default:
                queue.finishTransaction(transaction)
            }
        }
    }

    func purchaseProduct(product: SKProduct) {
        SKPaymentQueue.default().add(self)

        if SKPaymentQueue.canMakePayments() {
            let payment = SKPayment(product: product)
            SKPaymentQueue.default().add(payment)

        } else {
            DispatchQueue.main.async {[weak self] in
                self?.isError.toggle()
                self?.error = LocaleText.inAppsPurchaseTrx
            }

        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {[weak self] in
            self?.isError.toggle()
            self?.error = error.localizedDescription
        }
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {[weak self] in
            self?.isError = false
            self?.error = nil
        }

        if !response.products.isEmpty {
            for fetchedProduct in response.products {
                DispatchQueue.main.async {
                    self.myProducts.append(fetchedProduct)
                }
            }
        }
    }

    func getProducts(productIDs: [String]) {
        let request = SKProductsRequest(productIdentifiers: Set(productIDs))
        request.delegate = self
        request.start()
    }

    func getProductOnAppear() {
        if myProducts.isEmpty {
            getProducts(productIDs: productIDs)
        }
    }

    func onDisappear() {
        SKPaymentQueue.default().remove(self)
    }

    func routeToCoinHistory() {
        let viewModel = CoinHistoryViewModel(backToHome: { self.route = nil }, backToRoot: self.backToRoot)

        DispatchQueue.main.async { [weak self] in
            self?.route = .coinHistory(viewModel: viewModel)
        }
    }

    func routeToCreatorChoose() {
        let viewModel = FollowedCreatorViewModel(backToRoot: self.backToRoot, backToHome: { self.route = nil })

        DispatchQueue.main.async { [weak self] in
            self?.route = .followedCreator(viewModel: viewModel)
        }
    }
}

extension SKProduct: Identifiable {

}

