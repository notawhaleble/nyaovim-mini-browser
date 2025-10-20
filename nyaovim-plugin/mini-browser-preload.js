const {ipcRenderer} = require('electron');

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
