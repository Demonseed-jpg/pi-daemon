Alpine.data('chatPage', () => ({
  messages: [],
  input: '',
  isTyping: false,
  typingText: 'Thinking...',
  currentDelta: '',
  msgIdCounter: 0,
  selectedAgent: '',
  agents: [],

  init() {
    // Listen for WebSocket messages
    window.addEventListener('ws-message', (e) => this.handleWsMessage(e.detail));
    
    // Load available agents
    this.loadAgents();
    
    // Auto-resize textarea
    this.$watch('input', () => this.$nextTick(() => this.adjustTextareaHeight()));
  },

  async loadAgents() {
    try {
      const resp = await fetch('/api/agents');
      const data = await resp.json();
      this.agents = data;
      
      // Auto-select first agent if none selected
      if (!this.selectedAgent && data.length > 0) {
        this.selectedAgent = data[0].id;
      }
    } catch (e) {
      console.error('Failed to load agents:', e);
      this.agents = [];
    }
  },

  agentChanged() {
    // Clear messages when switching agents
    this.messages = [];
    this.isTyping = false;
    this.currentDelta = '';
  },

  handleWsMessage(msg) {
    console.log('Chat page received:', msg);
    
    switch (msg.type) {
      case 'typing':
        this.isTyping = msg.state !== 'stop';
        if (msg.state === 'tool' && msg.tool_name) {
          this.typingText = `Running ${msg.tool_name}...`;
        } else if (msg.state === 'start') {
          this.typingText = 'Thinking...';
        }
        break;
        
      case 'text_delta':
        if (!this.isTyping) {
          this.isTyping = true;
          this.typingText = 'Writing...';
        }
        this.currentDelta += msg.content;
        this.updateAssistantMessage(this.currentDelta);
        break;
        
      case 'response':
        this.isTyping = false;
        this.typingText = 'Thinking...';
        this.currentDelta = '';
        this.updateAssistantMessage(
          msg.content, 
          msg.input_tokens + msg.output_tokens,
          true // complete
        );
        break;
        
      case 'error':
        this.isTyping = false;
        this.addMessage('error', msg.content);
        break;
        
      case 'agents_updated':
        // Refresh agent list
        this.loadAgents();
        break;
        
      case 'pong':
        // Keepalive response, ignore
        break;
    }
    
    this.$nextTick(() => this.scrollToBottom());
  },

  updateAssistantMessage(content, tokens, complete = false) {
    const lastMsg = this.messages[this.messages.length - 1];
    
    if (lastMsg?.role === 'assistant' && !lastMsg.complete) {
      // Update existing message
      lastMsg.content = content;
      if (complete) {
        lastMsg.tokens = tokens;
        lastMsg.complete = true;
      }
    } else {
      // Add new message
      this.addMessage('assistant', content, tokens, complete);
    }
  },

  addMessage(role, content, tokens = null, complete = true) {
    this.messages.push({
      id: ++this.msgIdCounter,
      role,
      content,
      tokens,
      complete,
      timestamp: new Date().toISOString()
    });
  },

  sendMessage() {
    const text = this.input.trim();
    if (!text || !this.selectedAgent || !this.$root.wsConnected) {
      return;
    }

    // Add user message
    this.addMessage('user', text);
    
    // Send to WebSocket
    const sent = this.$root.sendWs({
      type: 'message',
      content: text
    });
    
    if (!sent) {
      this.addMessage('error', 'Failed to send message - WebSocket not connected');
      return;
    }

    // Clear input
    this.input = '';
    
    this.$nextTick(() => {
      this.adjustTextareaHeight();
      this.scrollToBottom();
    });
  },

  adjustTextareaHeight() {
    const textarea = this.$refs.input;
    if (!textarea) return;
    
    textarea.style.height = 'auto';
    const newHeight = Math.min(textarea.scrollHeight, 120); // max 120px
    textarea.style.height = newHeight + 'px';
  },

  scrollToBottom() {
    const container = this.$refs.messages;
    if (container) {
      container.scrollTop = container.scrollHeight;
    }
  },

  renderMarkdown(text) {
    // Use marked.js if available, otherwise use simple markdown
    if (window.marked) {
      return marked.parse(text);
    }
    
    // Simple markdown fallback
    return text
      .replace(/```([^`]+)```/g, '<pre><code>$1</code></pre>')
      .replace(/`([^`]+)`/g, '<code>$1</code>')
      .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
      .replace(/\*(.*?)\*/g, '<em>$1</em>')
      .replace(/\n/g, '<br>')
      // Escape HTML
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      // Restore markdown-generated tags
      .replace(/&lt;(\/?)(?:pre|code|strong|em|br)\b[^&]*&gt;/g, '<$1$2>');
  },

  // Keyboard shortcuts
  onKeyDown(event) {
    // Ctrl/Cmd + Enter to send
    if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
      event.preventDefault();
      this.sendMessage();
    }
  }
}));