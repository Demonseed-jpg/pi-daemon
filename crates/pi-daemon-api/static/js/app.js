document.addEventListener('alpine:init', () => {
  Alpine.data('app', () => ({
    page: 'chat',
    theme: localStorage.getItem('theme') || 'dark',
    version: '',
    wsConnected: false,
    agentCount: 0,
    ws: null,
    mobileMenuOpen: false,
    reconnectAttempts: 0,
    maxReconnectAttempts: 10,

    init() {
      this.fetchStatus();
      this.connectWebSocket();
      
      // Poll status every 30 seconds
      setInterval(() => this.fetchStatus(), 30000);
      
      // Set initial theme
      this.applyTheme();
      
      // Listen for hash changes for basic routing
      window.addEventListener('hashchange', () => {
        const hash = window.location.hash.slice(1);
        if (['chat', 'agents', 'overview', 'settings'].includes(hash)) {
          this.page = hash;
        }
      });
      
      // Set initial page from hash
      const initialHash = window.location.hash.slice(1);
      if (['chat', 'agents', 'overview', 'settings'].includes(initialHash)) {
        this.page = initialHash;
      }
    },

    async fetchStatus() {
      try {
        const resp = await fetch('/api/status');
        const data = await resp.json();
        this.version = data.version;
        this.agentCount = data.agent_count;
      } catch (e) {
        console.error('Status fetch failed:', e);
      }
    },

    connectWebSocket() {
      if (this.ws?.readyState === WebSocket.CONNECTING || this.ws?.readyState === WebSocket.OPEN) {
        return;
      }

      const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
      const url = `${protocol}//${location.host}/ws/webchat`;
      
      console.log('Connecting to WebSocket:', url);
      this.ws = new WebSocket(url);

      this.ws.onopen = () => {
        console.log('WebSocket connected');
        this.wsConnected = true;
        this.reconnectAttempts = 0;
      };

      this.ws.onclose = (event) => {
        console.log('WebSocket closed:', event.code, event.reason);
        this.wsConnected = false;
        
        // Exponential backoff for reconnection
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
          const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
          console.log(`Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts + 1})`);
          
          setTimeout(() => {
            this.reconnectAttempts++;
            this.connectWebSocket();
          }, delay);
        } else {
          console.error('Max reconnection attempts reached');
        }
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
      };

      this.ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data);
          console.log('WebSocket message:', msg);
          
          // Update agent count if agents_updated message
          if (msg.type === 'agents_updated') {
            this.agentCount = msg.agents.length;
          }
          
          // Dispatch to current page
          window.dispatchEvent(new CustomEvent('ws-message', { detail: msg }));
        } catch (e) {
          console.error('Failed to parse WebSocket message:', e);
        }
      };
    },

    reconnectWebSocket() {
      if (this.ws) {
        this.ws.close();
      }
      this.reconnectAttempts = 0;
      setTimeout(() => this.connectWebSocket(), 100);
    },

    sendWs(msg) {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify(msg));
        return true;
      }
      console.warn('WebSocket not connected, cannot send:', msg);
      return false;
    },

    toggleTheme() {
      this.theme = this.theme === 'dark' ? 'light' : 'dark';
      this.saveTheme();
    },

    saveTheme() {
      localStorage.setItem('theme', this.theme);
      this.applyTheme();
    },

    applyTheme() {
      document.documentElement.setAttribute('data-theme', this.theme);
    },

    // Navigation helpers
    navigateTo(page) {
      this.page = page;
      window.location.hash = page;
      this.mobileMenuOpen = false;
    },

    // Utility functions
    formatTime(timestamp) {
      if (!timestamp) return '';
      const date = new Date(timestamp);
      const now = new Date();
      const diffMs = now - date;
      const diffMins = Math.floor(diffMs / 60000);
      const diffHours = Math.floor(diffMins / 60);
      const diffDays = Math.floor(diffHours / 24);

      if (diffMins < 1) return 'just now';
      if (diffMins < 60) return `${diffMins}m ago`;
      if (diffHours < 24) return `${diffHours}h ago`;
      if (diffDays < 7) return `${diffDays}d ago`;
      
      return date.toLocaleDateString();
    },

    formatUptime(seconds) {
      if (!seconds) return '';
      
      const days = Math.floor(seconds / 86400);
      const hours = Math.floor((seconds % 86400) / 3600);
      const mins = Math.floor((seconds % 3600) / 60);
      
      if (days > 0) return `${days}d ${hours}h`;
      if (hours > 0) return `${hours}h ${mins}m`;
      return `${mins}m`;
    },

    // Simple markdown renderer (fallback if marked.js not available)
    simpleMarkdown(text) {
      return text
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.*?)\*/g, '<em>$1</em>')
        .replace(/`(.*?)`/g, '<code>$1</code>')
        .replace(/\n/g, '<br>')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
    }
  }));
});