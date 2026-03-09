use axum::http::header;
use axum::response::IntoResponse;

/// ETag for cache validation, based on crate version.
const ETAG: &str = concat!("\"pi-daemon-", env!("CARGO_PKG_VERSION"), "\"");

/// The full HTML page, assembled at compile time.
const WEBCHAT_HTML: &str = concat!(
    include_str!("../static/index_head.html"),
    "<style>\n",
    include_str!("../static/css/theme.css"),
    "\n",
    include_str!("../static/css/layout.css"),
    "\n",
    include_str!("../static/css/components.css"),
    "\n</style>\n",
    "<script defer>\n",
    include_str!("../static/vendor/alpine.min.js"),
    "\n</script>\n",
    "<script>\n",
    include_str!("../static/vendor/marked.min.js"),
    "\n",
    include_str!("../static/js/app.js"),
    "\n",
    include_str!("../static/js/pages/chat.js"),
    "\n",
    include_str!("../static/js/pages/agents.js"),
    "\n",
    include_str!("../static/js/pages/overview.js"),
    "\n",
    include_str!("../static/js/pages/settings.js"),
    "\n</script>\n",
    include_str!("../static/index_body.html"),
);

/// GET / — Serve the webchat SPA.
pub async fn webchat_page() -> impl IntoResponse {
    (
        [
            (header::CONTENT_TYPE, "text/html; charset=utf-8"),
            (header::ETAG, ETAG),
            (
                header::CACHE_CONTROL,
                "public, max-age=3600, must-revalidate",
            ),
        ],
        WEBCHAT_HTML,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::StatusCode;

    #[tokio::test]
    async fn test_webchat_page_returns_html() {
        let response = webchat_page().await.into_response();
        assert_eq!(response.status(), StatusCode::OK);

        // Check content type
        assert_eq!(
            response
                .headers()
                .get(header::CONTENT_TYPE)
                .unwrap()
                .to_str()
                .unwrap(),
            "text/html; charset=utf-8"
        );

        // Check ETag is present
        assert!(response.headers().get(header::ETAG).is_some());
    }

    #[test]
    fn test_webchat_html_contains_required_elements() {
        // Verify the assembled HTML contains required elements
        assert!(WEBCHAT_HTML.contains("<!DOCTYPE html>"));
        assert!(WEBCHAT_HTML.contains("PI-DAEMON"));
        assert!(WEBCHAT_HTML.contains("x-data=\"app\""));
        assert!(WEBCHAT_HTML.contains("Alpine"));
        assert!(WEBCHAT_HTML.contains("marked"));
    }

    #[test]
    fn test_etag_contains_version() {
        assert!(ETAG.contains(env!("CARGO_PKG_VERSION")));
    }
}
