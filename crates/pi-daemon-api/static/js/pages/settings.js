Alpine.data('settingsPage', () => ({
  autoReconnect: true,
  pingInterval: 30000, // 30 seconds
  maxMessageLength: 10000,
  enableNotifications: false,
  debugMode: false,
  
  init() {
    // Load settings from localStorage
    this.loadSettings();
    
    // Request notification permission if supported
    if ('Notification' in window && this.enableNotifications) {
      this.requestNotificationPermission();
    }
  },

  loadSettings() {
    const saved = localStorage.getItem('pi-daemon-settings');
    if (saved) {
      try {
        const settings = JSON.parse(saved);
        Object.assign(this, settings);
      } catch (e) {
        console.error('Failed to load settings:', e);
      }
    }
  },

  saveSettings() {
    const settings = {
      autoReconnect: this.autoReconnect,
      pingInterval: this.pingInterval,
      maxMessageLength: this.maxMessageLength,
      enableNotifications: this.enableNotifications,
      debugMode: this.debugMode
    };
    
    localStorage.setItem('pi-daemon-settings', JSON.stringify(settings));
    
    // Apply settings immediately
    this.applySettings();
  },

  applySettings() {
    // Enable/disable debug logging
    if (this.debugMode) {
      window.piDaemonDebug = true;
      console.log('Debug mode enabled');
    } else {
      window.piDaemonDebug = false;
    }
    
    // Request notification permission if enabled
    if (this.enableNotifications && 'Notification' in window) {
      this.requestNotificationPermission();
    }
  },

  async requestNotificationPermission() {
    if (!('Notification' in window)) {
      console.warn('Notifications not supported');
      return false;
    }
    
    if (Notification.permission === 'granted') {
      return true;
    }
    
    if (Notification.permission !== 'denied') {
      const permission = await Notification.requestPermission();
      return permission === 'granted';
    }
    
    return false;
  },

  getWebSocketUrl() {
    const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
    return `${protocol}//${location.host}/ws/webchat`;
  },

  getApiUrl() {
    return `${location.origin}/api`;
  },

  clearAllData() {
    if (!confirm('This will clear all local data including chat history, settings, and cached agent list. Continue?')) {
      return;
    }
    
    // Clear localStorage
    localStorage.removeItem('pi-daemon-settings');
    localStorage.removeItem('theme');
    
    // Clear any other stored data
    Object.keys(localStorage).forEach(key => {
      if (key.startsWith('pi-daemon-') || key.startsWith('chat-')) {
        localStorage.removeItem(key);
      }
    });
    
    // Reload page
    location.reload();
  },

  exportSettings() {
    const settings = {
      version: this.$root.version,
      exported_at: new Date().toISOString(),
      settings: {
        theme: this.$root.theme,
        autoReconnect: this.autoReconnect,
        pingInterval: this.pingInterval,
        maxMessageLength: this.maxMessageLength,
        enableNotifications: this.enableNotifications,
        debugMode: this.debugMode
      }
    };
    
    const dataStr = JSON.stringify(settings, null, 2);
    const dataBlob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(dataBlob);
    
    const link = document.createElement('a');
    link.href = url;
    link.download = `pi-daemon-settings-${new Date().toISOString().slice(0, 10)}.json`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  },

  async importSettings(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    try {
      const text = await file.text();
      const data = JSON.parse(text);
      
      if (data.settings) {
        // Import settings
        Object.assign(this, data.settings);
        this.$root.theme = data.settings.theme || 'dark';
        this.$root.saveTheme();
        this.saveSettings();
        
        alert('Settings imported successfully!');
      } else {
        throw new Error('Invalid settings file format');
      }
    } catch (e) {
      console.error('Failed to import settings:', e);
      alert(`Failed to import settings: ${e.message}`);
    }
    
    // Clear file input
    event.target.value = '';
  },

  testNotification() {
    if (!this.enableNotifications || !('Notification' in window)) {
      alert('Notifications are not enabled or supported');
      return;
    }
    
    if (Notification.permission === 'granted') {
      new Notification('Pi-daemon Test', {
        body: 'Notifications are working correctly!',
        icon: '/favicon.ico',
        tag: 'test'
      });
    } else {
      alert('Notification permission not granted');
    }
  },

  async testWebSocketConnection() {
    try {
      // Create a test WebSocket connection
      const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
      const url = `${protocol}//${location.host}/ws/test-connection`;
      const testWs = new WebSocket(url);
      
      const result = await Promise.race([
        new Promise((resolve) => {
          testWs.onopen = () => resolve('success');
          testWs.onerror = () => resolve('error');
        }),
        new Promise((resolve) => setTimeout(() => resolve('timeout'), 5000))
      ]);
      
      testWs.close();
      
      if (result === 'success') {
        alert('WebSocket connection test successful!');
      } else if (result === 'timeout') {
        alert('WebSocket connection test timed out');
      } else {
        alert('WebSocket connection test failed');
      }
    } catch (e) {
      alert(`WebSocket test error: ${e.message}`);
    }
  },

  getConnectionInfo() {
    return {
      userAgent: navigator.userAgent,
      url: location.href,
      webSocketUrl: this.getWebSocketUrl(),
      apiUrl: this.getApiUrl(),
      protocol: location.protocol,
      connected: this.$root.wsConnected,
      theme: this.$root.theme
    };
  }
}));