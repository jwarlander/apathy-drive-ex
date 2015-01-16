// Generated by CoffeeScript 1.7.1
(function() {
  (function(root, factory) {
    if (typeof define === "function" && define.amd) {
      return define(["phoenix"], factory);
    } else if (typeof exports === "object") {
      return factory(exports);
    } else {
      return factory((root.Phoenix = {}));
    }
  })(this, function(exports) {
    var root;
    root = this;
    exports.Channel = (function() {
      Channel.prototype.bindings = null;

      function Channel(topic, message, callback, socket) {
        this.topic = topic;
        this.message = message;
        this.callback = callback;
        this.socket = socket;
        this.reset();
      }

      Channel.prototype.reset = function() {
        return this.bindings = [];
      };

      Channel.prototype.on = function(event, callback) {
        return this.bindings.push({
          event: event,
          callback: callback
        });
      };

      Channel.prototype.isMember = function(topic) {
        return this.topic === topic;
      };

      Channel.prototype.off = function(event) {
        var bind;
        return this.bindings = (function() {
          var _i, _len, _ref, _results;
          _ref = this.bindings;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            bind = _ref[_i];
            if (bind.event !== event) {
              _results.push(bind);
            }
          }
          return _results;
        }).call(this);
      };

      Channel.prototype.trigger = function(triggerEvent, msg) {
        var callback, event, _i, _len, _ref, _ref1, _results;
        _ref = this.bindings;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          _ref1 = _ref[_i], event = _ref1.event, callback = _ref1.callback;
          if (event === triggerEvent) {
            _results.push(callback(msg));
          }
        }
        return _results;
      };

      Channel.prototype.send = function(event, payload) {
        return this.socket.send({
          topic: this.topic,
          event: event,
          payload: payload
        });
      };

      Channel.prototype.leave = function(message) {
        if (message == null) {
          message = {};
        }
        this.socket.leave(this.topic, message);
        return this.reset();
      };

      return Channel;

    })();
    exports.Socket = (function() {
      Socket.states = {
        connecting: 0,
        open: 1,
        closing: 2,
        closed: 3
      };

      Socket.prototype.conn = null;

      Socket.prototype.endPoint = null;

      Socket.prototype.channels = null;

      Socket.prototype.sendBuffer = null;

      Socket.prototype.sendBufferTimer = null;

      Socket.prototype.flushEveryMs = 50;

      Socket.prototype.reconnectTimer = null;

      Socket.prototype.reconnectAfterMs = 5000;

      Socket.prototype.heartbeatIntervalMs = 30000;

      Socket.prototype.stateChangeCallbacks = null;

      Socket.prototype.transport = null;

      function Socket(endPoint, opts) {
        var _ref, _ref1, _ref2, _ref3;
        if (opts == null) {
          opts = {};
        }
        this.states = exports.Socket.states;
        this.transport = (_ref = (_ref1 = opts.transport) != null ? _ref1 : root.WebSocket) != null ? _ref : exports.LongPoller;
        this.heartbeatIntervalMs = (_ref2 = opts.heartbeatIntervalMs) != null ? _ref2 : this.heartbeatIntervalMs;
        this.logger = (_ref3 = opts.logger) != null ? _ref3 : (function() {});
        this.endPoint = this.expandEndpoint(endPoint);
        this.channels = [];
        this.sendBuffer = [];
        this.stateChangeCallbacks = {
          open: [],
          close: [],
          error: [],
          message: []
        };
        this.resetBufferTimer();
        this.reconnect();
      }

      Socket.prototype.protocol = function() {
        if (location.protocol.match(/^https/)) {
          return "wss";
        } else {
          return "ws";
        }
      };

      Socket.prototype.expandEndpoint = function(endPoint) {
        if (endPoint.charAt(0) !== "/") {
          return endPoint;
        }
        if (endPoint.charAt(1) === "/") {
          return "" + (this.protocol()) + ":" + endPoint;
        }
        return "" + (this.protocol()) + "://" + location.host + endPoint;
      };

      Socket.prototype.close = function(callback, code, reason) {
        if (this.conn != null) {
          this.conn.onclose = (function(_this) {
            return function() {};
          })(this);
          if (code != null) {
            this.conn.close(code, reason != null ? reason : "");
          } else {
            this.conn.close();
          }
          this.conn = null;
        }
        return typeof callback === "function" ? callback() : void 0;
      };

      Socket.prototype.reconnect = function() {
        return this.close((function(_this) {
          return function() {
            _this.conn = new _this.transport(_this.endPoint);
            _this.conn.onopen = function() {
              return _this.onConnOpen();
            };
            _this.conn.onerror = function(error) {
              return _this.onConnError(error);
            };
            _this.conn.onmessage = function(event) {
              return _this.onConnMessage(event);
            };
            return _this.conn.onclose = function(event) {
              return _this.onConnClose(event);
            };
          };
        })(this));
      };

      Socket.prototype.resetBufferTimer = function() {
        clearTimeout(this.sendBufferTimer);
        return this.sendBufferTimer = setTimeout(((function(_this) {
          return function() {
            return _this.flushSendBuffer();
          };
        })(this)), this.flushEveryMs);
      };

      Socket.prototype.log = function(msg) {
        return this.logger(msg);
      };

      Socket.prototype.onOpen = function(callback) {
        if (callback) {
          return this.stateChangeCallbacks.open.push(callback);
        }
      };

      Socket.prototype.onClose = function(callback) {
        if (callback) {
          return this.stateChangeCallbacks.close.push(callback);
        }
      };

      Socket.prototype.onError = function(callback) {
        if (callback) {
          return this.stateChangeCallbacks.error.push(callback);
        }
      };

      Socket.prototype.onMessage = function(callback) {
        if (callback) {
          return this.stateChangeCallbacks.message.push(callback);
        }
      };

      Socket.prototype.onConnOpen = function() {
        var callback, _i, _len, _ref, _results;
        clearInterval(this.reconnectTimer);
        if (!this.transport.skipHeartbeat) {
          this.heartbeatTimer = setInterval(((function(_this) {
            return function() {
              return _this.sendHeartbeat();
            };
          })(this)), this.heartbeatIntervalMs);
        }
        this.rejoinAll();
        _ref = this.stateChangeCallbacks.open;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          callback = _ref[_i];
          _results.push(callback());
        }
        return _results;
      };

      Socket.prototype.onConnClose = function(event) {
        var callback, _i, _len, _ref, _results;
        this.log("WS close:");
        this.log(event);
        clearInterval(this.reconnectTimer);
        clearInterval(this.heartbeatTimer);
        this.reconnectTimer = setInterval(((function(_this) {
          return function() {
            return _this.reconnect();
          };
        })(this)), this.reconnectAfterMs);
        _ref = this.stateChangeCallbacks.close;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          callback = _ref[_i];
          _results.push(callback(event));
        }
        return _results;
      };

      Socket.prototype.onConnError = function(error) {
        var callback, _i, _len, _ref, _results;
        this.log("WS error:");
        this.log(error);
        _ref = this.stateChangeCallbacks.error;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          callback = _ref[_i];
          _results.push(callback(error));
        }
        return _results;
      };

      Socket.prototype.connectionState = function() {
        var _ref;
        switch ((_ref = this.conn) != null ? _ref.readyState : void 0) {
          case this.states.connecting:
            return "connecting";
          case this.states.open:
            return "open";
          case this.states.closing:
            return "closing";
          case this.states.closed:
          case null:
            return "closed";
        }
      };

      Socket.prototype.isConnected = function() {
        return this.connectionState() === "open";
      };

      Socket.prototype.rejoinAll = function() {
        var chan, _i, _len, _ref, _results;
        _ref = this.channels;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          chan = _ref[_i];
          _results.push(this.rejoin(chan));
        }
        return _results;
      };

      Socket.prototype.rejoin = function(chan) {
        var message, topic;
        chan.reset();
        topic = chan.topic, message = chan.message;
        this.send({
          topic: topic,
          event: "join",
          payload: message
        });
        return chan.callback(chan);
      };

      Socket.prototype.join = function(topic, message, callback) {
        var chan;
        chan = new exports.Channel(topic, message, callback, this);
        this.channels.push(chan);
        if (this.isConnected()) {
          return this.rejoin(chan);
        }
      };

      Socket.prototype.leave = function(topic, message) {
        var c;
        if (message == null) {
          message = {};
        }
        this.send({
          topic: topic,
          event: "leave",
          payload: message
        });
        return this.channels = (function() {
          var _i, _len, _ref, _results;
          _ref = this.channels;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            c = _ref[_i];
            if (!(c.isMember(topic))) {
              _results.push(c);
            }
          }
          return _results;
        }).call(this);
      };

      Socket.prototype.send = function(data) {
        var callback;
        callback = (function(_this) {
          return function() {
            return _this.conn.send(JSON.stringify(data));
          };
        })(this);
        if (this.isConnected()) {
          return callback();
        } else {
          return this.sendBuffer.push(callback);
        }
      };

      Socket.prototype.sendHeartbeat = function() {
        return this.send({
          topic: "phoenix",
          event: "heartbeat",
          payload: {}
        });
      };

      Socket.prototype.flushSendBuffer = function() {
        var callback, _i, _len, _ref;
        if (this.isConnected() && this.sendBuffer.length > 0) {
          _ref = this.sendBuffer;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            callback = _ref[_i];
            callback();
          }
          this.sendBuffer = [];
        }
        return this.resetBufferTimer();
      };

      Socket.prototype.onConnMessage = function(rawMessage) {
        var callback, chan, event, payload, topic, _i, _j, _len, _len1, _ref, _ref1, _ref2, _results;
        this.log("message received:");
        this.log(rawMessage);
        _ref = JSON.parse(rawMessage.data), topic = _ref.topic, event = _ref.event, payload = _ref.payload;
        _ref1 = this.channels;
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          chan = _ref1[_i];
          if (chan.isMember(topic)) {
            chan.trigger(event, payload);
          }
        }
        _ref2 = this.stateChangeCallbacks.message;
        _results = [];
        for (_j = 0, _len1 = _ref2.length; _j < _len1; _j++) {
          callback = _ref2[_j];
          _results.push(callback(topic, event, payload));
        }
        return _results;
      };

      return Socket;

    })();
    exports.LongPoller = (function() {
      LongPoller.prototype.retryInMs = 5000;

      LongPoller.prototype.endPoint = null;

      LongPoller.prototype.skipHeartbeat = true;

      LongPoller.prototype.onopen = function() {};

      LongPoller.prototype.onerror = function() {};

      LongPoller.prototype.onmessage = function() {};

      LongPoller.prototype.onclose = function() {};

      function LongPoller(endPoint) {
        this.states = exports.Socket.states;
        this.upgradeEndpoint = this.normalizeEndpoint(endPoint);
        this.pollEndpoint = this.upgradeEndpoint + (/\/$/.test(endPoint) ? "poll" : "/poll");
        this.readyState = this.states.connecting;
        this.open();
      }

      LongPoller.prototype.open = function() {
        return exports.Ajax.request("POST", this.upgradeEndpoint, "application/json", null, (function(_this) {
          return function(status, resp) {
            if (status === 200) {
              _this.readyState = _this.states.open;
              _this.onopen();
              return _this.poll();
            } else {
              return _this.onerror();
            }
          };
        })(this));
      };

      LongPoller.prototype.normalizeEndpoint = function(endPoint) {
        return endPoint.replace("ws://", "http://").replace("wss://", "https://");
      };

      LongPoller.prototype.poll = function() {
        if (this.readyState !== this.states.open) {
          return;
        }
        return exports.Ajax.request("GET", this.pollEndpoint, "application/json", null, (function(_this) {
          return function(status, resp) {
            var msg, _i, _len, _ref;
            switch (status) {
              case 200:
                _ref = JSON.parse(resp);
                for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                  msg = _ref[_i];
                  _this.onmessage({
                    data: JSON.stringify(msg)
                  });
                }
                return _this.poll();
              case 204:
                return _this.poll();
              default:
                _this.close();
                return setTimeout((function() {
                  return _this.open();
                }), _this.retryInMs);
            }
          };
        })(this));
      };

      LongPoller.prototype.send = function(body) {
        return exports.Ajax.request("POST", this.pollEndpoint, "application/json", body, (function(_this) {
          return function(status, resp) {
            if (status !== 200) {
              return _this.onerror();
            }
          };
        })(this));
      };

      LongPoller.prototype.close = function(code, reason) {
        this.readyState = this.states.closed;
        return this.onclose();
      };

      return LongPoller;

    })();
    exports.Ajax = {
      states: {
        complete: 4
      },
      request: function(method, endPoint, accept, body, callback) {
        var req;
        req = root.XMLHttpRequest != null ? new root.XMLHttpRequest() : new root.ActiveXObject("Microsoft.XMLHTTP");
        req.open(method, endPoint, true);
        req.setRequestHeader("Content-type", accept);
        req.onreadystatechange = (function(_this) {
          return function() {
            if (req.readyState === _this.states.complete) {
              return typeof callback === "function" ? callback(req.status, req.responseText) : void 0;
            }
          };
        })(this);
        return req.send(body);
      }
    };
    return exports;
  });

}).call(this);