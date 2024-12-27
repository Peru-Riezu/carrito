const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld
(
	'electronAPI',
	{
		getCodes: () => ipcRenderer.invoke('get-codes'),
		openPath: () => ipcRenderer.send('open-file-explorer', 'C:\\Users\\riezu\\Desktop\\carrito\\carrito_front_end'),
		onLog: (callback) => ipcRenderer.on('log', callback)
	}
);
