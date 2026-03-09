//! Integration tests for test-utils crate.

use pi_daemon_test_utils::{TestClient, TestKernel, TestServer};

#[test]
fn test_kernel_integration() {
    let kernel = TestKernel::new();
    assert!(kernel.data_dir.exists());
    assert!(kernel.data_dir.is_dir());
}

#[tokio::test]
async fn test_server_client_integration() {
    let server = TestServer::new().await;
    let client = TestClient::new(&server.base_url);

    // Test health endpoint
    let resp = client.get("/api/health").await;
    assert_eq!(resp.status().as_u16(), 200);

    let body = resp.text().await.expect("Failed to read response body");
    assert!(body.contains("status"));
    assert!(body.contains("ok"));
}
