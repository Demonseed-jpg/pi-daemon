/// Assert a JSON response matches expected status and contains a key.
///
/// This macro checks that the response is successful, parses the JSON,
/// and verifies that the specified key exists in the response.
#[macro_export]
macro_rules! assert_json_ok {
    ($resp:expr, $key:expr) => {{
        assert!(
            $resp.status().is_success(),
            "Expected success, got {}",
            $resp.status()
        );
        let json: serde_json::Value = $resp.json().await.expect("Failed to parse JSON response");
        assert!(
            json.get($key).is_some(),
            "Expected key '{}' in response: {:?}",
            $key,
            json
        );
        json
    }};
}

/// Assert response status code matches expected value.
///
/// Provides detailed error message including response body on mismatch.
#[macro_export]
macro_rules! assert_status {
    ($resp:expr, $status:expr) => {
        assert_eq!(
            $resp.status().as_u16(),
            $status,
            "Expected status {}, got {}. Response body: {:?}",
            $status,
            $resp.status().as_u16(),
            $resp.text().await.unwrap_or_default()
        );
    };
}
