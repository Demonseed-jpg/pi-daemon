Alpine.data('agentsPage', () => ({
  agents: [],
  loading: false,
  error: null,

  async init() {
    this.loadAgents();
    
    // Listen for agent updates
    window.addEventListener('ws-message', (e) => {
      if (e.detail.type === 'agents_updated') {
        this.agents = e.detail.agents;
      }
    });
    
    // Refresh agents every 30 seconds
    setInterval(() => this.loadAgents(), 30000);
  },

  async loadAgents() {
    this.loading = true;
    this.error = null;
    
    try {
      const resp = await fetch('/api/agents');
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}: ${resp.statusText}`);
      }
      
      const data = await resp.json();
      this.agents = data;
    } catch (e) {
      console.error('Failed to load agents:', e);
      this.error = e.message;
    } finally {
      this.loading = false;
    }
  },

  getAgentStatusClass(agent) {
    switch (agent.status) {
      case 'idle':
        return 'online';
      case 'busy':
        return 'busy';
      case 'error':
        return 'error';
      default:
        return 'offline';
    }
  },

  getAgentStatusText(agent) {
    // Show last heartbeat time if available
    if (agent.last_heartbeat) {
      const lastSeen = this.$root.formatTime(agent.last_heartbeat);
      return `${agent.status} • ${lastSeen}`;
    }
    
    return agent.status;
  },

  formatAgentKind(kind) {
    // Convert snake_case to Title Case
    return kind
      .split('_')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  },

  async deleteAgent(agentId) {
    if (!confirm('Are you sure you want to unregister this agent?')) {
      return;
    }
    
    try {
      const resp = await fetch(`/api/agents/${agentId}`, {
        method: 'DELETE'
      });
      
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}: ${resp.statusText}`);
      }
      
      // Remove from local list
      this.agents = this.agents.filter(agent => agent.id !== agentId);
      
    } catch (e) {
      console.error('Failed to delete agent:', e);
      alert(`Failed to delete agent: ${e.message}`);
    }
  },

  async sendHeartbeat(agentId) {
    try {
      const resp = await fetch(`/api/agents/${agentId}/heartbeat`, {
        method: 'POST'
      });
      
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}: ${resp.statusText}`);
      }
      
      // Refresh agents list
      this.loadAgents();
      
    } catch (e) {
      console.error('Failed to send heartbeat:', e);
      alert(`Failed to send heartbeat: ${e.message}`);
    }
  },

  getTimeSinceRegistration(timestamp) {
    if (!timestamp) return '';
    
    const registered = new Date(timestamp);
    const now = new Date();
    const diffMs = now - registered;
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const diffHours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    
    if (diffDays > 0) {
      return `${diffDays}d ${diffHours}h ago`;
    } else if (diffHours > 0) {
      return `${diffHours}h ago`;
    } else {
      return 'Recently';
    }
  }
}));