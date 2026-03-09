fn main() {
    println!("pi-daemon v{}", env!("CARGO_PKG_VERSION"));
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_version_output() {
        // Simple test to verify basic functionality
        assert!(!env!("CARGO_PKG_VERSION").is_empty());
    }
}
