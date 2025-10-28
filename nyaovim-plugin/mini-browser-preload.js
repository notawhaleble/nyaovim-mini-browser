const {ipcRenderer} = require('electron');

let overlayId = null;

ipcRenderer.on('mini-browser:set-overlay-id', (_event, id) => {
  overlayId = id;
});

function forwardBrowserNotification(title, options) {
  const payload = {
    overlayId,
    title: typeof title === 'string' ? title : '',
    body: options && typeof options.body === 'string' ? options.body : '',
    tag: options && typeof options.tag === 'string' ? options.tag : undefined,
    icon: options && typeof options.icon === 'string' ? options.icon : undefined,
    silent: options ? !!options.silent : undefined,
    renotify: options ? !!options.renotify : undefined,
    requireInteraction: options ? !!options.requireInteraction : undefined,
    timestamp: Date.now(),
  };
  if (options && options.data !== undefined) {
    try {
      payload.data = JSON.parse(JSON.stringify(options.data));
    } catch (_err) {
      payload.data = undefined;
    }
  }
  ipcRenderer.sendToHost('mini-browser:notification', payload);
}

const NativeNotification = typeof window !== 'undefined' ? window.Notification : null;

if (typeof NativeNotification === 'function') {
  const NotificationProxy = function NotificationProxy(title, options) {
    const instance = Reflect.construct(
      NativeNotification,
      [title, options],
      new.target || NotificationProxy,
    );
    try {
      forwardBrowserNotification(title, options || {});
    } catch (err) {
      console.error('[mini-browser] forwarding notification failed', err);
    }
    return instance;
  };

  NotificationProxy.prototype = NativeNotification.prototype;
  Object.defineProperty(NotificationProxy.prototype, 'constructor', {
    value: NotificationProxy,
    writable: true,
    configurable: true,
  });
  Object.setPrototypeOf(NotificationProxy, NativeNotification);

  Object.defineProperty(NotificationProxy, 'permission', {
    configurable: true,
    enumerable: true,
    get() {
      return NativeNotification.permission;
    },
  });

  Object.defineProperty(NotificationProxy, 'maxActions', {
    configurable: true,
    enumerable: true,
    get() {
      return NativeNotification.maxActions;
    },
  });

  NotificationProxy.requestPermission = NativeNotification.requestPermission
    ? NativeNotification.requestPermission.bind(NativeNotification)
    : undefined;

  window.Notification = NotificationProxy;
}

window.addEventListener(
  'keydown',
  event => {
    const key = event.key ? event.key.toLowerCase() : '';
    const code = event.code || '';
    if ((event.ctrlKey || event.metaKey) && (key === ']' || code === 'BracketRight')) {
      ipcRenderer.sendToHost('mini-browser:toggle');
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if ((event.ctrlKey || event.metaKey) && (key === 'r' || code === 'KeyR')) {
      ipcRenderer.sendToHost('mini-browser:reload', {
        ignoreCache: !!event.shiftKey,
      });
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if ((event.ctrlKey || event.metaKey) && (key === '+' || key === '=' || code === 'Equal' || code === 'NumpadAdd')) {
      ipcRenderer.sendToHost('mini-browser:zoom-in');
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if (
      (event.ctrlKey || event.metaKey) &&
      (key === '-' || key === '_' || code === 'Minus' || code === 'NumpadSubtract')
    ) {
      ipcRenderer.sendToHost('mini-browser:zoom-out');
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if ((event.ctrlKey || event.metaKey) && (key === 'o' || code === 'KeyO')) {
      ipcRenderer.sendToHost('mini-browser:history-back');
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if ((event.ctrlKey || event.metaKey) && (key === 'i' || code === 'KeyI')) {
      ipcRenderer.sendToHost('mini-browser:history-forward');
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if ((event.ctrlKey || event.metaKey) && (key === 'w' || code === 'KeyW')) {
      ipcRenderer.sendToHost('mini-browser:ctrl-w');
      event.preventDefault();
      event.stopPropagation();
    }
  },
  true,
);

window.addEventListener('keyup', event => {
  const key = event.key ? event.key.toLowerCase() : '';
  const code = event.code || '';
  if ((event.ctrlKey || event.metaKey) && (key === ']' || code === 'BracketRight')) {
    event.preventDefault();
    event.stopPropagation();
  }
  if ((event.ctrlKey || event.metaKey) && (key === 'r' || code === 'KeyR')) {
    event.preventDefault();
    event.stopPropagation();
  }
  if ((event.ctrlKey || event.metaKey) && (key === '+' || key === '=' || code === 'Equal' || code === 'NumpadAdd')) {
    event.preventDefault();
    event.stopPropagation();
  }
  if (
    (event.ctrlKey || event.metaKey) &&
    (key === '-' || key === '_' || code === 'Minus' || code === 'NumpadSubtract')
  ) {
    event.preventDefault();
    event.stopPropagation();
  }
  if ((event.ctrlKey || event.metaKey) && (key === 'o' || code === 'KeyO')) {
    event.preventDefault();
    event.stopPropagation();
  }
  if ((event.ctrlKey || event.metaKey) && (key === 'i' || code === 'KeyI')) {
    event.preventDefault();
    event.stopPropagation();
  }
}, true);

window.addEventListener('focus', () => {
  ipcRenderer.sendToHost('mini-browser:focus', true);
}, true);

window.addEventListener('blur', () => {
  ipcRenderer.sendToHost('mini-browser:focus', false);
}, true);

window.addEventListener(
  'mousedown',
  () => {
    ipcRenderer.sendToHost('mini-browser:mouse-down');
  },
  true,
);
