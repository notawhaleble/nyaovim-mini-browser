const {ipcRenderer} = require('electron');

window.addEventListener('keydown', event => {
  const key = event.key ? event.key.toLowerCase() : '';
  if ((event.ctrlKey || event.metaKey) && key === ']') {
    ipcRenderer.sendToHost('mini-browser:toggle');
    event.preventDefault();
    event.stopPropagation();
  }
}, true);

window.addEventListener('keyup', event => {
  const key = event.key ? event.key.toLowerCase() : '';
  if ((event.ctrlKey || event.metaKey) && key === ']') {
    event.preventDefault();
    event.stopPropagation();
  }
}, true);
