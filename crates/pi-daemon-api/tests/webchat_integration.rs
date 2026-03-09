//! Webchat UI integration tests

use pi_daemon_api::server::build_router;
use pi_daemon_kernel::PiDaemonKernel;
use pi_daemon_types::config::DaemonConfig;
use std::sync::Arc;
use tokio::net::TcpListener;

async fn start_test_server() -> String {
    let kernel = Arc::new(PiDaemonKernel::new());
    kernel.init().await;

    let config = DaemonConfig {
        listen_addr: "127.0.0.1:0".to_string(),
        ..Default::default()
    };

    let (router, _state) = build_router(kernel, config);

    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();

    tokio::spawn(async move {
        axum::serve(
            listener,
            router.into_make_service_with_connect_info::<std::net::SocketAddr>(),
        )
        .await
        .unwrap();
    });

    // Give the server a moment to start
    tokio::time::sleep(std::time::Duration::from_millis(100)).await;

    format!("http://127.0.0.1:{}", addr.port())
}

#[tokio::test]
async fn test_webchat_page_loads() {
    let base_url = start_test_server().await;
    let client = reqwest::Client::new();

    let response = client.get(&base_url).send().await.unwrap();

    // Should return 200 OK
    assert_eq!(response.status(), 200);

    // Should have correct content type
    assert_eq!(
        response.headers().get("content-type").unwrap(),
        "text/html; charset=utf-8"
    );

    // Should have ETag header for caching
    assert!(response.headers().get("etag").is_some());

    let body = response.text().await.unwrap();

    // Should contain HTML structure
    assert!(body.contains("<!DOCTYPE html>"));
    assert!(body.contains("<html"));
    assert!(body.contains("</html>"));

    // Should contain pi-daemon branding
    assert!(body.contains("PI-DAEMON"));

    // Should contain Alpine.js app setup
    assert!(body.contains("x-data=\"app\""));

    // Should contain JavaScript
    assert!(body.contains("Alpine"));
    assert!(body.contains("marked"));

    // Should contain CSS
    assert!(body.contains("var(--bg-primary)"));

    // Should be substantial (not just a placeholder)
    assert!(body.len() > 50000); // Should be >50KB with all assets
}

#[tokio::test]
async fn test_webchat_etag_consistency() {
    let base_url = start_test_server().await;
    let client = reqwest::Client::new();

    // First request
    let response1 = client.get(&base_url).send().await.unwrap();

    let etag1 = response1.headers().get("etag").unwrap().to_str().unwrap();

    // Second request should have the same ETag (content hasn't changed)
    let response2 = client.get(&base_url).send().await.unwrap();

    let etag2 = response2.headers().get("etag").unwrap().to_str().unwrap();

    assert_eq!(etag1, etag2);
    assert!(etag1.contains(env!("CARGO_PKG_VERSION")));
}

#[tokio::test]
async fn test_webchat_performance() {
    let base_url = start_test_server().await;
    let client = reqwest::Client::new();

    let start = std::time::Instant::now();

    let response = client.get(&base_url).send().await.unwrap();

    let duration = start.elapsed();

    // Should load in under 500ms (single HTML response)
    assert!(duration.as_millis() < 500);

    // Should be successful
    assert_eq!(response.status(), 200);

    let body = response.text().await.unwrap();

    // Body should contain expected content
    assert!(body.contains("PI-DAEMON"));
}

#[tokio::test]
async fn test_webchat_static_asset_embedding() {
    let base_url = start_test_server().await;
    let client = reqwest::Client::new();

    let response = client.get(&base_url).send().await.unwrap();

    let body = response.text().await.unwrap();

    // Should contain embedded Alpine.js (check for Alpine.js specific code)
    assert!(body.contains("Alpine"));

    // Should contain embedded marked.js (check for marked specific code)
    assert!(body.contains("marked"));

    // Should contain custom app JavaScript
    assert!(body.contains("Alpine.data('app'"));
    assert!(body.contains("Alpine.data('chatPage'"));
    assert!(body.contains("Alpine.data('agentsPage'"));
    assert!(body.contains("Alpine.data('overviewPage'"));
    assert!(body.contains("Alpine.data('settingsPage'"));

    // Should contain CSS variables for theming
    assert!(body.contains("--bg-primary"));
    assert!(body.contains("--text-primary"));

    // Should contain the complete HTML structure
    assert!(body.contains("sidebar"));
    assert!(body.contains("main-content"));
    assert!(body.contains("chat-page"));
}

#[tokio::test]
async fn test_webchat_no_external_requests() {
    let base_url = start_test_server().await;
    let client = reqwest::Client::new();

    let response = client.get(&base_url).send().await.unwrap();

    let body = response.text().await.unwrap();

    // Should not contain any external CDN references
    assert!(!body.contains("unpkg.com"));
    assert!(!body.contains("cdnjs.cloudflare.com"));
    assert!(!body.contains("jsdelivr.net"));
    assert!(!body.contains("googleapis.com"));

    // Should not contain external script/link tags
    assert!(!body.contains("src=\"http"));
    assert!(!body.contains("href=\"http"));

    // All assets should be embedded
    assert!(body.contains("<style>"));
    assert!(body.contains("<script"));
    assert!(body.contains("</style>"));
    assert!(body.contains("</script>"));
}
