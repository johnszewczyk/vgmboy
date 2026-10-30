import UIKit

@main
@MainActor
final class AppBoyAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = AppBoySceneDelegate.self
        return config
    }
}

@objc(AppBoySceneDelegate)
@MainActor
final class AppBoySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var rootController: AppViewController?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let controller = AppViewController()
        let hostWindow = UIWindow(windowScene: windowScene)
        hostWindow.backgroundColor = UIColor(red: 9.0 / 255.0, green: 11.0 / 255.0, blue: 15.0 / 255.0, alpha: 1.0)
        hostWindow.rootViewController = controller
        hostWindow.makeKeyAndVisible()
        self.rootController = controller
        self.window = hostWindow
    }

    func sceneWillResignActive(_ scene: UIScene) {
        flushInBackground()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        flushInBackground()
    }

    private func flushInBackground() {
        guard let controller = rootController else { return }
        let app = UIApplication.shared
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = app.beginBackgroundTask(withName: "APPBOY.StateFlush") {
            if bgTask != .invalid {
                app.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        Task { @MainActor in
            await controller.flushFrontendState()
            if bgTask != .invalid {
                app.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
    }
}
