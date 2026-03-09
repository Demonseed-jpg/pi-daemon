Alpine.data('overviewPage', () => ({
  version: '',
  uptime: 0,
  agentCount: 0,
  events: [],
  loading: false,
  error: null,

  async init() {
    this.loadStatus();
    this.loadEvents();
    
    // Refresh data every 30 seconds
    setInterval(() => {
      this.loadStatus();
      this.loadEvents();
    }, 30000);
    
    // Sync with main app state
    this.$watch('$root.version', (value) => this.version = value);
    this.$watch('$root.agentCount', (value) => this.agentCount = value);
  },

  async loadStatus() {
    try {
      const resp = await fetch('/api/status');
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}: ${resp.statusText}`);
      }
      
      const data = await resp.json();
      this.version = data.version;
      this.uptime = data.uptime_secs;
      this.agentCount = data.agent_count;
      
      // Sync back to main app
      this.$root.version = data.version;
      this.$root.agentCount = data.agent_count;
      
    } catch (e) {
      console.error('Failed to load status:', e);
      this.error = e.message;
    }
  },

  async loadEvents() {
    this.loading = true;
    
    try {
      const resp = await fetch('/api/events');
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}: ${resp.statusText}`);
      }
      
      const data = await resp.json();
      // Show only the most recent 10 events
      this.events = data.slice(0, 10);
      
    } catch (e) {
      console.error('Failed to load events:', e);
      this.events = [];
    } finally {
      this.loading = false;
    }
  },

  formatUptime(seconds) {
    return this.$root.formatUptime(seconds);
  },

  formatTime(timestamp) {
    return this.$root.formatTime(timestamp);
  },

  getEventDescription(event) {
    const { type, name } = event.payload;
    
    switch (type) {
      case 'AgentRegistered':
        return `Agent "${name}" registered`;
      case 'AgentUnregistered':
        return `Agent "${name}" unregistered`;
      case 'SystemStarted':
        return 'System started';
      case 'HeartbeatReceived':
        return `Heartbeat from "${name}"`;
      case 'StatusChanged':
        return `Status changed for "${name}"`;
      default:
        return type;
    }
  },

  getEventIcon(eventType) {
    switch (eventType) {
      case 'AgentRegistered':
        return '🤖';
      case 'AgentUnregistered':
        return '👋';
      case 'SystemStarted':
        return '🚀';
      case 'HeartbeatReceived':
        return '💓';
      case 'StatusChanged':
        return '🔄';
      default:
        return '📝';
    }
  },

  getUptimeColor() {
    if (this.uptime < 3600) return 'var(--warning)'; // < 1 hour
    if (this.uptime < 86400) return 'var(--info)';   // < 1 day
    return 'var(--success)'; // > 1 day
  },

  getAgentCountColor() {
    if (this.agentCount === 0) return 'var(--error)';
    if (this.agentCount < 3) return 'var(--warning)';
    return 'var(--success)';
  },

  async exportSystemInfo() {
    const systemInfo = {
      timestamp: new Date().toISOString(),
      version: this.version,
      uptime_seconds: this.uptime,
      agent_count: this.agentCount,
      websocket_connected: this.$root.wsConnected,
      recent_events: this.events,
      user_agent: navigator.userAgent,
      url: location.href
    };
    
    const dataStr = JSON.stringify(systemInfo, null, 2);
    const dataBlob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(dataBlob);
    
    const link = document.createElement('a');
    link.href = url;
    link.download = `pi-daemon-info-${new Date().toISOString().slice(0, 19).replace(/:/g, '-')}.json`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }
}));