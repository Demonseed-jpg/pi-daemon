//! Shared test utilities for pi-daemon.

pub mod client;
pub mod kernel;
pub mod macros;
pub mod server;

// Re-export main types for convenience
pub use client::TestClient;
pub use kernel::TestKernel;
pub use server::TestServer;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_kernel_helper_creates_temp_dir() {
        let kernel = TestKernel::new();
        assert!(kernel.data_dir.exists());
    }

    #[tokio::test]
    async fn test_server_starts_successfully() {
        let server = TestServer::new().await;
        assert!(server.base_url.starts_with("http://127.0.0.1:"));
        assert!(server.port > 0);
    }

    #[test]
    fn test_client_helper_construction() {
        let client = TestClient::new("http://localhost:3000");
        assert_eq!(client.base_url, "http://localhost:3000");
    }
}
